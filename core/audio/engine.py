import os
import pygame
from PyQt6.QtCore import QObject, QTimer, pyqtSignal, pyqtProperty, QPropertyAnimation, QEasingCurve
from typing import Dict, List
from .models import Theme, MusicState, Track

# PyGame Mixer'ı Başlat (Sadece 1 kere)
try:
    pygame.mixer.init(frequency=44100, size=-16, channels=2, buffer=2048)
    pygame.mixer.set_num_channels(32) # Aynı anda 32 ses çalabilir
except Exception as e:
    print(f"Audio Init Error: {e}")

class TrackPlayer(QObject):
    """
    PyGame Sound nesnesini yöneten sarmalayıcı.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.sound = None
        self.channel = None # PyGame Channel
        self._volume = 0.0 # 0.0 - 1.0
        
        # Animasyon için property
        self.anim = QPropertyAnimation(self, b"volume")
        self.anim.setDuration(2000)
        self.anim.setEasingCurve(QEasingCurve.Type.InOutQuad)

    @pyqtProperty(float)
    def volume(self):
        return self._volume

    @volume.setter
    def volume(self, val):
        self._volume = val
        if self.channel:
            self.channel.set_volume(val)

    def load_track(self, track: Track):
        if not track.sequence: return
        
        # Sadece ilk dosyayı yükler (Basit loop mantığı için)
        # Gelişmiş sequence mantığı için burası genişletilebilir
        node = track.sequence[0]
        if os.path.exists(node.file_path):
            try:
                self.sound = pygame.mixer.Sound(node.file_path)
            except Exception as e:
                print(f"Load Error ({node.file_path}): {e}")
        else:
            print(f"⚠️ Missing: {node.file_path}")

    def play(self):
        if self.sound:
            # loops=-1 (Sonsuz)
            self.channel = self.sound.play(loops=-1)
            if self.channel:
                self.channel.set_volume(self._volume)

    def stop(self):
        if self.sound:
            self.sound.stop()
    
    def fade_to(self, target, duration=1000):
        self.anim.stop()
        self.anim.setDuration(duration)
        self.anim.setStartValue(self._volume)
        self.anim.setEndValue(target)
        self.anim.start()

class MultiTrackDeck(QObject):
    """
    Bir 'State'i (Normal, Combat) yönetir.
    PyGame kanallarını senkronize başlatır.
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.players: Dict[str, TrackPlayer] = {} 
        self.master_volume = 0.0 
        self.intensity_levels = ["base"]

    @pyqtProperty(float)
    def deck_volume(self): return self.master_volume
    @deck_volume.setter
    def deck_volume(self, val):
        self.master_volume = val
        self.update_mix()

    def load_state(self, state: MusicState):
        self.stop()
        self.players.clear()

        for track_id, track_data in state.tracks.items():
            tp = TrackPlayer(self)
            tp.load_track(track_data)
            self.players[track_id] = tp

    def play(self):
        # PyGame'de sesler "neredeyse" aynı anda başlar.
        # Daha hassas senkronizasyon için buffer ayarı önemlidir.
        for p in self.players.values():
            p.volume = 0.0
            p.play()
        self.update_mix()

    def stop(self):
        for p in self.players.values(): p.stop()

    def set_intensity_mask(self, levels: List[str]):
        self.intensity_levels = levels
        self.update_mix()

    def update_mix(self):
        for pid, player in self.players.items():
            is_active = pid in self.intensity_levels
            target = self.master_volume if is_active else 0.0
            player.fade_to(target, 1000)

class MusicBrain(QObject):
    """
    İki MultiTrackDeck arasında geçiş yapar.
    """
    def __init__(self):
        super().__init__()
        self._fade_ratio = 1.0 
        self.global_volume = 0.5
        
        self.deck_a = MultiTrackDeck(self)
        self.deck_b = MultiTrackDeck(self)
        
        self.active_deck = self.deck_a
        self.inactive_deck = self.deck_b
        
        self.anim = QPropertyAnimation(self, b"fade_ratio")
        self.anim.setDuration(2000)
        
        self.current_theme: Theme = None
        self.current_state_id = None
        self.current_intensity_level = 0

    @pyqtProperty(float)
    def fade_ratio(self): return self._fade_ratio
    @fade_ratio.setter
    def fade_ratio(self, val):
        self._fade_ratio = val
        self.active_deck.deck_volume = self.global_volume * val
        self.inactive_deck.deck_volume = self.global_volume * (1.0 - val)

    def set_theme(self, theme: Theme):
        self.current_theme = theme
        start_state = "normal" if "normal" in theme.states else list(theme.states.keys())[0]
        self._hard_switch(start_state)

    def set_state(self, state_name: str):
        if not self.current_theme or state_name not in self.current_theme.states: return
        if state_name == self.current_state_id: return
        
        print(f"🔄 State Change: {state_name}")
        target_state = self.current_theme.states[state_name]
        
        self.inactive_deck.load_state(target_state)
        self.inactive_deck.set_intensity_mask(self._get_mask_for_level(self.current_intensity_level))
        self.inactive_deck.deck_volume = 0.0
        self.inactive_deck.play()
        
        old_active = self.active_deck
        self.active_deck = self.inactive_deck
        self.inactive_deck = old_active
        self.current_state_id = state_name
        
        self.anim.stop()
        self.anim.setStartValue(0.0)
        self.anim.setEndValue(1.0)
        self.anim.start()

    def set_intensity(self, level: int):
        self.current_intensity_level = level
        mask = self._get_mask_for_level(level)
        print(f"🎚️ Intensity: {level} -> {mask}")
        self.active_deck.set_intensity_mask(mask)
        self.inactive_deck.set_intensity_mask(mask)

    def _get_mask_for_level(self, level):
        active = ["base"]
        if level >= 1: active.append("level1")
        if level >= 2: active.append("level2")
        if level >= 3: active.append("level3")
        return active

    def _hard_switch(self, state_name):
        if not self.current_theme: return
        state = self.current_theme.states.get(state_name)
        if not state: return
        
        self.active_deck.stop()
        self.inactive_deck.stop()
        
        self.active_deck.load_state(state)
        self.active_deck.set_intensity_mask(self._get_mask_for_level(self.current_intensity_level))
        self.active_deck.deck_volume = self.global_volume
        self.active_deck.play()
        
        self._fade_ratio = 1.0
        self.current_state_id = state_name

    def set_volume(self, val):
        self.global_volume = val
        self.active_deck.deck_volume = val * self._fade_ratio
        self.inactive_deck.deck_volume = val * (1.0 - self._fade_ratio)

    def stop(self):
        self.active_deck.stop()
        self.inactive_deck.stop()