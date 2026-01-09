import os
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput
from PyQt6.QtCore import QUrl, QObject, pyqtSignal, QPropertyAnimation, QEasingCurve, pyqtProperty
from typing import Dict, List
from .models import Theme, MusicState, Track

class TrackPlayer(QObject):
    """
    Tek bir izi (Track) yöneten oynatıcı.
    """
    loop_finished = pyqtSignal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self.player = QMediaPlayer()
        self.audio = QAudioOutput()
        self.player.setAudioOutput(self.audio)
        
        self._volume = 0.0 
        self.audio.setVolume(0.0)
        
        # Loop tespiti için değişken
        self.last_position = 0
        
        self.anim = QPropertyAnimation(self, b"volume")
        self.anim.setDuration(2000)
        self.anim.setEasingCurve(QEasingCurve.Type.InOutQuad)

        # Pozisyon takibi (Sonsuz döngüde başa sarmayı anlamak için)
        self.player.positionChanged.connect(self._on_position_changed)

    @pyqtProperty(float)
    def volume(self): return self._volume
    
    @volume.setter
    def volume(self, val):
        if abs(self._volume - val) > 0.001:
            self._volume = val
            self.audio.setVolume(val)

    def load_track(self, track: Track):
        if not track.sequence: return
        node = track.sequence[0]
        
        if os.path.exists(node.file_path):
            self.player.setSource(QUrl.fromLocalFile(os.path.abspath(node.file_path)))
            
            # --- DÜZELTME: Sonsuz Döngü ---
            # Once yerine Infinite kullanıyoruz. Bu, Qt'nin native gapless playback 
            # özelliklerini (desteklenen formatlarda) kullanmasını sağlar.
            self.player.setLoops(QMediaPlayer.Loops.Infinite) 
            self.last_position = 0
        else:
            print(f"⚠️ Dosya Yok: {node.file_path}")

    def play(self):
        if self.player.source().isValid():
            self.player.play()

    def stop(self):
        self.player.stop()
        self.last_position = 0
    
    def fade_to(self, target, duration=1500):
        if abs(self._volume - target) < 0.01 and self.anim.state() != QPropertyAnimation.State.Running:
            return
        if self.anim.state() == QPropertyAnimation.State.Running and abs(self.anim.endValue() - target) < 0.01:
            return
        if self.anim.state() == QPropertyAnimation.State.Running:
            self.anim.stop()
        
        self.anim.setDuration(duration)
        self.anim.setStartValue(self._volume)
        self.anim.setEndValue(target)
        self.anim.start()

    def _on_position_changed(self, position):
        """
        Infinite Loop modunda 'EndOfMedia' sinyali gelmez.
        Bu yüzden şarkının süresi sıfırlandığında (başa döndüğünde) döngüyü biz tespit ederiz.
        """
        # Eğer pozisyon aniden azaldıysa (örn: 50000ms -> 100ms), başa sarmış demektir.
        if position < self.last_position and position < 500: # 500ms tolerans
            # Sinyal gönder (Queue sistemi çalışsın diye)
            self.loop_finished.emit()
        
        self.last_position = position

class MultiTrackDeck(QObject):
    """
    Bir 'State'i (Normal, Combat) yönetir.
    TrackPlayer'ları senkronize başlatır.
    """
    loop_finished = pyqtSignal() # Ana loop bittiğinde sinyal verir

    def __init__(self, parent=None):
        super().__init__(parent)
        self.players: Dict[str, TrackPlayer] = {} 
        self.master_volume = 0.0 
        self.active_levels = ["base"]

    @pyqtProperty(float)
    def deck_volume(self): return self.master_volume
    @deck_volume.setter
    def deck_volume(self, val):
        # Gereksiz güncellemeyi önle
        if abs(self.master_volume - val) > 0.001:
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
            
        # Sinyal Bağlantısı: 'base' kanalını lider kabul et
        if "base" in self.players:
            self.players["base"].loop_finished.connect(self.loop_finished.emit)
        elif self.players:
            list(self.players.values())[0].loop_finished.connect(self.loop_finished.emit)

    def play(self):
        for p in self.players.values():
            p.volume = 0.0 
            p.play()
        self.update_mix()

    def stop(self):
        for p in self.players.values(): p.stop()

    def set_intensity_mask(self, levels: List[str]):
        # Eğer maske değişmediyse işlem yapma (Freeze önleyici)
        if self.active_levels == levels:
            return
            
        self.active_levels = levels
        self.update_mix()

    def update_mix(self):
        for pid, player in self.players.items():
            is_active = pid in self.active_levels
            target = self.master_volume if is_active else 0.0
            player.fade_to(target, duration=1500)

class MusicBrain(QObject):
    """
    İki MultiTrackDeck arasında State geçişi yapar.
    """
    state_changed = pyqtSignal(str) # UI Güncellemesi İçin

    def __init__(self):
        super().__init__()
        
        self._fade_ratio = 1.0 
        self.global_volume = 0.5
        
        self.deck_a = MultiTrackDeck(self)
        self.deck_b = MultiTrackDeck(self)
        
        # Sinyalleri bağla (Loop bitince kontrol et)
        self.deck_a.loop_finished.connect(self._check_queue)
        self.deck_b.loop_finished.connect(self._check_queue)
        
        self.active_deck = self.deck_a
        self.inactive_deck = self.deck_b
        
        self.anim = QPropertyAnimation(self, b"fade_ratio")
        self.anim.setDuration(2000)
        
        self.current_theme: Theme = None
        self.current_state_id = None
        self.pending_state_id = None # Bekleyen geçiş
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
        self.pending_state_id = None
        start_state = "normal" if "normal" in theme.states else list(theme.states.keys())[0]
        self._hard_switch(start_state)

    def queue_state(self, state_name):
        """Sıradaki loop bitince geçilecek."""
        if state_name == self.current_state_id: return
        self.pending_state_id = state_name
        print(f"⏳ Kuyruğa Alındı: {state_name}")

    def force_transition(self):
        """Beklemeyi iptal et ve hemen geç."""
        if self.pending_state_id:
            print(f"🚀 Zorla Geçiş: {self.pending_state_id}")
            self.set_state(self.pending_state_id)
            self.pending_state_id = None

    def _check_queue(self):
        """Loop bittiğinde çağrılır."""
        if self.pending_state_id:
            print("✅ Loop bitti, otomatik geçiş.")
            self.set_state(self.pending_state_id)
            self.pending_state_id = None

    def set_state(self, state_name: str):
        if not self.current_theme or state_name not in self.current_theme.states: return
        if state_name == self.current_state_id: return
        
        print(f"🔄 State Change: {state_name}")
        target_state = self.current_theme.states[state_name]
        
        # 1. Hazırla
        self.inactive_deck.load_state(target_state)
        self.inactive_deck.set_intensity_mask(self._get_mask_for_level(self.current_intensity_level))
        self.inactive_deck.deck_volume = 0.0
        self.inactive_deck.play()
        
        # 2. Değiştir
        old_active = self.active_deck
        self.active_deck = self.inactive_deck
        self.inactive_deck = old_active
        self.current_state_id = state_name
        
        # 3. Cross-Fade
        self.anim.stop()
        self.anim.setStartValue(0.0)
        self.anim.setEndValue(1.0)
        self.anim.start()
        
        self.state_changed.emit(state_name)

    def set_intensity(self, level: int):
        # Donmayı önlemek için gereksiz yere aynı seviyeyi set etme
        if self.current_intensity_level == level:
            return

        self.current_intensity_level = level
        mask = self._get_mask_for_level(level)
        
        # Sadece maskeyi güncelle
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
        self.state_changed.emit(state_name)

    def set_volume(self, val):
        self.global_volume = val
        self.active_deck.deck_volume = val * self._fade_ratio
        self.inactive_deck.deck_volume = val * (1.0 - self._fade_ratio)

    def stop(self):
        self.pending_state_id = None
        self.active_deck.stop()
        self.inactive_deck.stop()