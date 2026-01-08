import os
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput
from PyQt6.QtCore import QUrl, QObject, pyqtSignal, QPropertyAnimation, QEasingCurve, pyqtProperty
from typing import Dict, List
from .models import Theme, MusicState, Track

class TrackPlayer(QObject):
    """Tek bir Track'i (örn: Combat -> Level1) çalar."""
    def __init__(self, parent=None):
        super().__init__(parent)
        self.player = QMediaPlayer()
        self.audio = QAudioOutput()
        self.player.setAudioOutput(self.audio)
        
        self.current_track: Track = None
        self.seq_index = 0
        self.loop_counter = 0
        
        self._volume = 0.0
        self.audio.setVolume(0.0)
        
        self.anim = QPropertyAnimation(self, b"volume")
        self.anim.setDuration(2000)
        self.anim.setEasingCurve(QEasingCurve.Type.InOutQuad)

        self.player.mediaStatusChanged.connect(self._on_media_status)

    @pyqtProperty(float)
    def volume(self): return self._volume
    @volume.setter
    def volume(self, val):
        self._volume = val
        self.audio.setVolume(val)

    def load_track(self, track: Track):
        self.current_track = track
        self.seq_index = 0
        self.loop_counter = 0
        self._prepare_next()

    def _prepare_next(self):
        if not self.current_track or not self.current_track.sequence: return
        node = self.current_track.sequence[self.seq_index]
        if os.path.exists(node.file_path):
            self.player.setSource(QUrl.fromLocalFile(os.path.abspath(node.file_path)))
        else:
            print(f"⚠️ Dosya Yok: {node.file_path}")

    def play(self):
        if self.player.source().isValid(): self.player.play()
    def stop(self): self.player.stop()
    
    def fade_to(self, target, duration=1000):
        self.anim.stop()
        self.anim.setDuration(duration)
        self.anim.setStartValue(self._volume)
        self.anim.setEndValue(target)
        self.anim.start()

    def _on_media_status(self, status):
        if status == QMediaPlayer.MediaStatus.EndOfMedia:
            if not self.current_track: return
            node = self.current_track.sequence[self.seq_index]
            self.loop_counter += 1
            
            if node.repeat_count > 0 and self.loop_counter >= node.repeat_count:
                self.seq_index += 1
                self.loop_counter = 0
                if self.seq_index >= len(self.current_track.sequence): self.seq_index = 0
                self._prepare_next()
                self.player.play()
            else:
                self.player.play()

class MultiTrackDeck(QObject):
    """
    Bir 'State'i (Normal, Combat) yönetir.
    Intensity ayarına göre içindeki tracklerin sesini açar/kısar.
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
        for p in self.players.values():
            p.stop(); p.deleteLater()
        self.players.clear()

        for track_id, track_data in state.tracks.items():
            tp = TrackPlayer(self)
            tp.load_track(track_data)
            self.players[track_id] = tp

    def play(self):
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
    İki MultiTrackDeck arasında State geçişi yapar.
    """
    def __init__(self):
        super().__init__()
        
        # --- KRİTİK DÜZELTME: Önce değişkenleri tanımla ---
        self._fade_ratio = 1.0 # 1.0 = Active %100, Inactive %0
        self.global_volume = 0.5
        
        self.deck_a = MultiTrackDeck(self)
        self.deck_b = MultiTrackDeck(self)
        
        self.active_deck = self.deck_a
        self.inactive_deck = self.deck_b
        
        # Animasyonu en son tanımla
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
        # Decklerin Master Volume'unu ayarla
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