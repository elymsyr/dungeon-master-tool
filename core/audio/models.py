from dataclasses import dataclass, field
from typing import List, Dict

@dataclass
class LoopNode:
    """A single audio file with its repeat count."""
    file_path: str
    repeat_count: int = 0  # 0 = infinite loop, 1 = play once

@dataclass
class Track:
    """
    Intensity channel (e.g. 'base', 'level1').
    Holds an ordered sequence of LoopNodes.
    """
    name: str
    sequence: List[LoopNode] = field(default_factory=list)

@dataclass
class MusicState:
    """
    Music State/Mode (e.g. 'Normal', 'Combat', 'Victory').
    Contains multiple intensity levels (Tracks).
    """
    name: str
    tracks: Dict[str, Track] = field(default_factory=dict)

@dataclass
class Theme:
    """
    Top-level music theme (e.g. 'Forest').
    Contains a set of States.
    """
    name: str
    id: str = ""
    states: Dict[str, MusicState] = field(default_factory=dict)
