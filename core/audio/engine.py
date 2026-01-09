import os
from PyQt6.QtMultimedia import QMediaPlayer, QAudioOutput
from PyQt6.QtCore import QUrl, QObject, pyqtSignal, QPropertyAnimation, QEasingCurve, pyqtProperty
from typing import Dict, List
from .models import Theme, MusicState, Track

# --- YARDIMCI SINIFLAR (DEĞİŞİKLİK YOK) ---

class TrackPlayer(QObject):
    loop_finished = pyqtSignal()
    def __init__(self, parent=None):
        super().__init__(parent)
        self.player = QMediaPlayer(); self.audio = QAudioOutput()
        self.player.setAudioOutput(self.audio); self._volume = 0.0 
        self.audio.setVolume(self._volume); self.last_position = 0
        self.anim = QPropertyAnimation(self, b"volume"); self.anim.setDuration(2000)
        self.anim.setEasingCurve(QEasingCurve.Type.InOutQuad)
        self.player.positionChanged.connect(self._on_position_changed)
    @pyqtProperty(float)
    def volume(self): return self._volume
    @volume.setter
    def volume(self, val): self._volume = val; self.audio.setVolume(val)
    def load_track(self, track: Track):
        if not track.sequence: return
        node = track.sequence[0]
        if os.path.exists(node.file_path):
            self.player.setSource(QUrl.fromLocalFile(os.path.abspath(node.file_path)))
            self.player.setLoops(QMediaPlayer.Loops.Infinite); self.last_position = 0
    def play(self): self.player.play()
    def stop(self): self.player.stop(); self.last_position = 0
    def fade_to(self, target, duration=1500):
        if self.anim.state() == QPropertyAnimation.State.Running: self.anim.stop()
        self.anim.setDuration(duration)
        self.anim.setStartValue(self._volume); self.anim.setEndValue(target); self.anim.start()
    def _on_position_changed(self, position):
        if position < self.last_position and position < 500: self.loop_finished.emit()
        self.last_position = position

class MultiTrackDeck(QObject):
    loop_finished = pyqtSignal()
    def __init__(self, parent=None):
        super().__init__(parent)
        self.players: Dict[str, TrackPlayer] = {}; self.master_volume = 0.0; self.active_levels = ["base"]
    @pyqtProperty(float)
    def deck_volume(self): return self.master_volume
    @deck_volume.setter
    def deck_volume(self, val): self.master_volume = val; self.update_mix()
    def load_state(self, state: MusicState):
        for p in self.players.values(): p.stop(); p.deleteLater()
        self.players.clear()
        for track_id, track_data in state.tracks.items():
            tp = TrackPlayer(self); tp.load_track(track_data); self.players[track_id] = tp
        if "base" in self.players: self.players["base"].loop_finished.connect(self.loop_finished.emit)
    def play(self):
        for p in self.players.values(): p.volume = 0.0; p.play()
        self.update_mix()
    def stop(self):
        for p in self.players.values(): p.stop()
    def set_intensity_mask(self, levels: List[str]):
        self.active_levels = levels; self.update_mix()
    def update_mix(self):
        for pid, player in self.players.items():
            target = self.master_volume if pid in self.active_levels else 0.0
            player.fade_to(target, duration=1500)

# --- ANA KONTROL SINIFI ---

class MusicBrain(QObject):
    state_changed = pyqtSignal(str)
    def __init__(self):
        super().__init__()
        self.global_music_volume = 0.5; self._fade_ratio = 1.0 
        self.anim = QPropertyAnimation(self, b"fade_ratio"); self.anim.setDuration(2000)
        self.deck_a = MultiTrackDeck(self); self.deck_b = MultiTrackDeck(self)
        self.active_deck = self.deck_a; self.inactive_deck = self.deck_b
        self.deck_a.loop_finished.connect(self._check_queue); self.deck_b.loop_finished.connect(self._check_queue)
        self.current_theme: Theme = None; self.current_state_id = None
        self.pending_state_id = None; self.current_intensity_level = 0
        self.AMBIENCE_PLAYER_COUNT = 4; self.ambience_players = []
        for _ in range(self.AMBIENCE_PLAYER_COUNT):
            player = QMediaPlayer(); audio_output = QAudioOutput()
            player.setAudioOutput(audio_output); player.setLoops(QMediaPlayer.Loops.Infinite)
            self.ambience_players.append({'player': player, 'output': audio_output, 'id': None})
        self.SFX_PLAYER_COUNT = 8; self.sfx_pool = []
        for _ in range(self.SFX_PLAYER_COUNT):
            player = QMediaPlayer(); audio_output = QAudioOutput()
            player.setAudioOutput(audio_output)
            self.sfx_pool.append({'player': player, 'output': audio_output, 'busy': False})

    @pyqtProperty(float)
    def fade_ratio(self): return self._fade_ratio
    @fade_ratio.setter
    def fade_ratio(self, val):
        self._fade_ratio = val
        self.active_deck.deck_volume = self.global_music_volume * val
        self.inactive_deck.deck_volume = self.global_music_volume * (1.0 - val)

    def set_theme(self, theme: Theme):
        self.current_theme = theme; self.pending_state_id = None
        if theme and theme.states:
            start_state = list(theme.states.keys())[0]
            self._hard_switch(start_state)
        else: self.active_deck.stop(); self.inactive_deck.stop()

    def set_state(self, state_name: str):
        if not self.current_theme or state_name not in self.current_theme.states or state_name == self.current_state_id: return
        target_state = self.current_theme.states[state_name]
        self.inactive_deck.load_state(target_state)
        self.inactive_deck.set_intensity_mask(self._get_mask_for_level(self.current_intensity_level))
        self.inactive_deck.deck_volume = 0.0; self.inactive_deck.play()
        self.active_deck, self.inactive_deck = self.inactive_deck, self.active_deck
        self.current_state_id = state_name
        self.anim.stop(); self.anim.setStartValue(0.0); self.anim.setEndValue(1.0); self.anim.start()
        self.state_changed.emit(state_name)

    def set_intensity(self, level: int):
        self.current_intensity_level = level
        mask = self._get_mask_for_level(level)
        self.active_deck.set_intensity_mask(mask); self.inactive_deck.set_intensity_mask(mask)

    def queue_state(self, state_name): self.pending_state_id = state_name
    def _check_queue(self):
        if self.pending_state_id: self.set_state(self.pending_state_id); self.pending_state_id = None
    
    # --- YENİ EKLENEN YARDIMCI METOT (HATAYI DÜZELTEN KISIM) ---
    def _get_mask_for_level(self, level: int) -> List[str]:
        """
        Yoğunluk seviyesini (örn: 2) bir katman listesine çevirir (örn: ['base', 'level1', 'level2']).
        """
        return ["base"] + [f"level{i+1}" for i in range(level)]

    def _hard_switch(self, state_name):
        self.active_deck.stop(); self.inactive_deck.stop()
        state = self.current_theme.states.get(state_name)
        if not state: return
        self.active_deck.load_state(state)
        self.active_deck.set_intensity_mask(self._get_mask_for_level(self.current_intensity_level))
        self.active_deck.deck_volume = self.global_music_volume; self.active_deck.play()
        self._fade_ratio = 1.0; self.current_state_id = state_name; self.state_changed.emit(state_name)

    def play_ambience(self, slot_index, file_path, volume):
        if not (0 <= slot_index < self.AMBIENCE_PLAYER_COUNT): return
        slot = self.ambience_players[slot_index]; player = slot['player']
        if not file_path: player.stop(); slot['id'] = None; return
        if os.path.exists(file_path):
            player.setSource(QUrl.fromLocalFile(os.path.abspath(file_path)))
            slot['output'].setVolume(volume / 100.0)
            player.play(); slot['id'] = os.path.basename(file_path)

    def set_ambience_volume(self, slot_index, volume):
        if 0 <= slot_index < self.AMBIENCE_PLAYER_COUNT:
            self.ambience_players[slot_index]['output'].setVolume(volume / 100.0)

    def stop_ambience(self):
        for slot in self.ambience_players: slot['player'].stop(); slot['id'] = None

    def play_sfx(self, file_path, volume=1.0):
        if not os.path.exists(file_path): return
        for slot in self.sfx_pool:
            if not slot['busy']:
                slot['busy'] = True; player = slot['player']
                handler = lambda status, s=slot: self._on_sfx_finished(status, s)
                player.mediaStatusChanged.connect(handler)
                slot['handler'] = handler; slot['output'].setVolume(volume)
                player.setSource(QUrl.fromLocalFile(os.path.abspath(file_path)))
                player.play(); return

    def _on_sfx_finished(self, status, slot):
        if status == QMediaPlayer.MediaStatus.EndOfMedia:
            if slot.get('handler'):
                try: slot['player'].mediaStatusChanged.disconnect(slot['handler'])
                except TypeError: pass
                del slot['handler']
            slot['busy'] = False

    def set_master_volume(self, volume):
        self.global_music_volume = volume
        self.active_deck.deck_volume = self.global_music_volume * self._fade_ratio
        self.inactive_deck.deck_volume = self.global_music_volume * (1.0 - self._fade_ratio)

    def stop_all(self):
        self.pending_state_id = None; self.active_deck.stop(); self.inactive_deck.stop()
        self.stop_ambience()