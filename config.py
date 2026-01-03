import os

# Projenin çalıştığı ana dizini bul
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
# Dünyaların kaydedileceği klasör
WORLDS_DIR = os.path.join(BASE_DIR, "worlds")

API_BASE_URL = "https://www.dnd5eapi.co/api"

STYLESHEET = """
/* ... (Eski stylesheet kodları aynen kalacak) ... */
QMainWindow { background-color: #1e1e1e; }
QWidget { font-family: 'Segoe UI', sans-serif; font-size: 14px; color: #e0e0e0; }
QListWidget { background-color: #252526; border: 1px solid #3e3e42; border-radius: 4px; padding: 5px; }
QListWidget::item { padding: 8px; border-bottom: 1px solid #333; }
QListWidget::item:selected { background-color: #37373d; color: #ffffff; border-left: 3px solid #007acc; }
QLineEdit, QTextEdit, QComboBox { background-color: #3c3c3c; border: 1px solid #555; border-radius: 4px; padding: 5px; color: white; }
QLineEdit:focus, QTextEdit:focus { border: 1px solid #007acc; }
QGroupBox { border: 1px solid #555; border-radius: 6px; margin-top: 20px; font-weight: bold; }
QGroupBox::title { subcontrol-origin: margin; subcontrol-position: top left; padding: 0 5px; color: #007acc; }
QPushButton { background-color: #3c3c3c; border: 1px solid #555; border-radius: 4px; padding: 6px 12px; font-weight: bold; }
QPushButton:hover { background-color: #505050; }
QPushButton#primaryBtn { background-color: #007acc; border: none; color: white; }
QPushButton#primaryBtn:hover { background-color: #0062a3; }
QPushButton#dangerBtn { background-color: #ce3838; border: none; color: white; }
QPushButton#dangerBtn:hover { background-color: #a81010; }
QPushButton#successBtn { background-color: #2e7d32; border: none; color: white; }
QPushButton#successBtn:hover { background-color: #1b5e20; }
QTabWidget::pane { border: 1px solid #3e3e42; top: -1px; }
QTabBar::tab { background: #2d2d2d; color: #aaa; padding: 8px 20px; border: 1px solid #3e3e42; margin-right: 2px; }
QTabBar::tab:selected { background: #1e1e1e; color: white; border-top: 2px solid #007acc; }
"""