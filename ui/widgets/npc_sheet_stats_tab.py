"""NpcSheetStatsTab — D&D stats, combat stats, and defense fields."""

from PyQt6.QtCore import Qt
from PyQt6.QtWidgets import (
    QFormLayout,
    QGroupBox,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QVBoxLayout,
    QWidget,
)

from core.locales import tr


class NpcSheetStatsTab(QWidget):
    """Stats, combat stats, and defense sections for the NpcSheet Stats tab."""

    def __init__(self, dirty_callback, palette: dict, parent=None):
        super().__init__(parent)
        self._dirty = dirty_callback
        self.current_palette = palette
        self.stats_inputs: dict[str, QLineEdit] = {}
        self.stats_modifiers: dict[str, QLabel] = {}
        self._init_ui()

    # ------------------------------------------------------------------
    # UI setup
    # ------------------------------------------------------------------

    def _init_ui(self) -> None:
        layout = QVBoxLayout(self)

        # --- Base stats (STR/DEX/…) ---
        self.grp_base_stats = QGroupBox(tr("GRP_STATS"))
        base_row = QHBoxLayout(self.grp_base_stats)
        for s in ["STR", "DEX", "CON", "INT", "WIS", "CHA"]:
            col = QVBoxLayout()
            lbl = QLabel(s)
            lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl.setObjectName("statAbbrev")
            inp = QLineEdit("10")
            inp.setAlignment(Qt.AlignmentFlag.AlignCenter)
            inp.setMaximumWidth(50)
            inp.textChanged.connect(lambda text, key=s: self._update_modifier(key, text))
            lbl_mod = QLabel("+0")
            lbl_mod.setAlignment(Qt.AlignmentFlag.AlignCenter)
            lbl_mod.setProperty("class", "statModifier")
            self.stats_inputs[s] = inp
            self.stats_modifiers[s] = lbl_mod
            col.addWidget(lbl)
            col.addWidget(inp)
            col.addWidget(lbl_mod)
            base_row.addLayout(col)
        layout.addWidget(self.grp_base_stats)

        # --- Combat stats ---
        self.grp_combat_stats = QGroupBox(tr("GRP_COMBAT"))
        v_comb = QVBoxLayout(self.grp_combat_stats)
        self.inp_hp = QLineEdit()
        self.inp_hp.setPlaceholderText(tr("LBL_HP"))
        self.inp_max_hp = QLineEdit()
        self.inp_max_hp.setPlaceholderText(tr("LBL_MAX_HP"))
        self.inp_ac = QLineEdit()
        self.inp_ac.setPlaceholderText(tr("HEADER_AC"))
        self.inp_speed = QLineEdit()
        self.inp_prof = QLineEdit()
        self.inp_pp = QLineEdit()
        self.inp_init = QLineEdit()
        self.inp_init.setPlaceholderText(tr("LBL_INIT"))

        r1 = QHBoxLayout()
        for t, w in [
            (tr("LBL_MAX_HP"), self.inp_max_hp),
            (tr("LBL_HP"), self.inp_hp),
            (tr("HEADER_AC"), self.inp_ac),
            (tr("LBL_SPEED"), self.inp_speed),
        ]:
            col = QVBoxLayout()
            col.addWidget(QLabel(t))
            col.addWidget(w)
            r1.addLayout(col)

        r2 = QHBoxLayout()
        for t, w in [
            (tr("LBL_PROF_BONUS"), self.inp_prof),
            (tr("LBL_PASSIVE_PERC"), self.inp_pp),
            (tr("LBL_INIT_BONUS"), self.inp_init),
        ]:
            col = QVBoxLayout()
            col.addWidget(QLabel(t))
            col.addWidget(w)
            r2.addLayout(col)

        v_comb.addLayout(r1)
        v_comb.addLayout(r2)
        layout.addWidget(self.grp_combat_stats)

        # --- Defense ---
        self.grp_defense = QGroupBox(tr("GRP_DEFENSE"))
        form = QFormLayout(self.grp_defense)
        self.inp_saves = QLineEdit()
        self.inp_skills = QLineEdit()
        self.inp_vuln = QLineEdit()
        self.inp_resist = QLineEdit()
        self.inp_dmg_immune = QLineEdit()
        self.inp_cond_immune = QLineEdit()
        form.addRow(tr("LBL_SAVES"), self.inp_saves)
        form.addRow(tr("LBL_SKILLS"), self.inp_skills)
        form.addRow(tr("LBL_VULN"), self.inp_vuln)
        form.addRow(tr("LBL_RESIST"), self.inp_resist)
        form.addRow(tr("LBL_DMG_IMMUNE"), self.inp_dmg_immune)
        form.addRow(tr("LBL_COND_IMMUNE"), self.inp_cond_immune)
        layout.addWidget(self.grp_defense)
        layout.addStretch()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def connect_dirty_signals(self, callback) -> None:
        all_inputs = [
            self.inp_hp, self.inp_max_hp, self.inp_ac, self.inp_speed,
            self.inp_prof, self.inp_pp, self.inp_init,
            self.inp_saves, self.inp_skills, self.inp_vuln, self.inp_resist,
            self.inp_dmg_immune, self.inp_cond_immune,
        ]
        all_inputs.extend(self.stats_inputs.values())
        for w in all_inputs:
            w.textChanged.connect(callback)

    def populate(self, data: dict) -> None:
        stats = data.get("stats", {})
        for k, inp in self.stats_inputs.items():
            inp.setText(str(stats.get(k, 10)))
            self._update_modifier(k, inp.text())

        c = data.get("combat_stats", {})
        self.inp_hp.setText(str(c.get("hp", "") or ""))
        self.inp_max_hp.setText(str(c.get("max_hp", "") or ""))
        self.inp_ac.setText(str(c.get("ac", "") or ""))
        self.inp_speed.setText(str(c.get("speed", "") or ""))
        self.inp_init.setText(str(c.get("initiative", "") or ""))
        self.inp_saves.setText(str(data.get("saving_throws", "") or ""))
        self.inp_skills.setText(str(data.get("skills", "") or ""))
        self.inp_vuln.setText(str(data.get("damage_vulnerabilities", "") or ""))
        self.inp_resist.setText(str(data.get("damage_resistances", "") or ""))
        self.inp_dmg_immune.setText(str(data.get("damage_immunities", "") or ""))
        self.inp_cond_immune.setText(str(data.get("condition_immunities", "") or ""))
        self.inp_prof.setText(str(data.get("proficiency_bonus", "") or ""))
        self.inp_pp.setText(str(data.get("passive_perception", "") or ""))

    def collect(self) -> dict:
        return {
            "stats": {k: int(v.text() or 10) for k, v in self.stats_inputs.items()},
            "combat_stats": {
                "hp": self.inp_hp.text(),
                "max_hp": self.inp_max_hp.text(),
                "ac": self.inp_ac.text(),
                "speed": self.inp_speed.text(),
                "initiative": self.inp_init.text(),
            },
            "saving_throws": self.inp_saves.text(),
            "skills": self.inp_skills.text(),
            "damage_vulnerabilities": self.inp_vuln.text(),
            "damage_resistances": self.inp_resist.text(),
            "damage_immunities": self.inp_dmg_immune.text(),
            "condition_immunities": self.inp_cond_immune.text(),
            "proficiency_bonus": self.inp_prof.text(),
            "passive_perception": self.inp_pp.text(),
        }

    def set_edit_mode(self, enabled: bool) -> None:
        ro = not enabled
        for w in [
            self.inp_hp, self.inp_max_hp, self.inp_ac, self.inp_speed,
            self.inp_prof, self.inp_pp, self.inp_init,
            self.inp_saves, self.inp_skills, self.inp_vuln, self.inp_resist,
            self.inp_dmg_immune, self.inp_cond_immune,
        ]:
            w.setReadOnly(ro)
        for w in self.stats_inputs.values():
            w.setReadOnly(ro)

    def refresh_theme(self, palette: dict) -> None:
        self.current_palette = palette
        for key, inp in self.stats_inputs.items():
            self._update_modifier(key, inp.text())

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _update_modifier(self, stat_key: str, text_value: str) -> None:
        try:
            val = int(text_value)
            mod = (val - 10) // 2
            sign = "+" if mod >= 0 else ""
            self.stats_modifiers[stat_key].setText(f"{sign}{mod}")
            if mod > 0:
                self.stats_modifiers[stat_key].setStyleSheet(
                    f"color: {self.current_palette.get('hp_bar_full', '#4caf50')}; font-weight: bold;"
                )
            else:
                self.stats_modifiers[stat_key].setStyleSheet(
                    f"color: {self.current_palette.get('html_dim', '#aaa')}; font-weight: normal;"
                )
        except ValueError:
            self.stats_modifiers[stat_key].setText("-")
