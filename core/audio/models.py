from dataclasses import dataclass, field
from typing import List, Dict

@dataclass
class LoopNode:
    """Tek bir ses dosyası ve tekrar sayısı."""
    file_path: str
    repeat_count: int = 0  # 0 = Sonsuz, 1 = Bir kere çal

@dataclass
class Track:
    """
    Intensity kanalı (Örn: 'base', 'level1').
    Kendi içinde sıralı dosya listesi (sequence) barındırır.
    """
    name: str
    sequence: List[LoopNode] = field(default_factory=list)

@dataclass
class MusicState:
    """
    Müzik Durumu/Modu (Örn: 'Normal', 'Combat', 'Victory').
    İçinde farklı intensity seviyeleri (Track) barındırır.
    """
    name: str
    tracks: Dict[str, Track] = field(default_factory=dict)

@dataclass
class Theme:
    """
    Ana Tema (Örn: 'Forest').
    Durumları (States) barındırır.
    """
    name: str
    id: str = ""
    states: Dict[str, MusicState] = field(default_factory=dict)
