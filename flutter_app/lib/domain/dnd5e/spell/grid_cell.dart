/// Integer cell on a 5 ft battlemap grid. `col` = x, `row` = y.
class GridCell {
  final int col;
  final int row;

  const GridCell(this.col, this.row);

  static const double feetPerCell = 5;

  GridCell translate(int dCol, int dRow) => GridCell(col + dCol, row + dRow);

  /// Chebyshev (king-move) distance in cells per SRD §8.2 grid rule.
  int chebyshevTo(GridCell other) {
    final dx = (col - other.col).abs();
    final dy = (row - other.row).abs();
    return dx > dy ? dx : dy;
  }

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.col == col && other.row == row;
  @override
  int get hashCode => Object.hash(col, row);
  @override
  String toString() => 'GridCell($col, $row)';
}

/// Cardinal face direction for anchored AoEs (Cone/Cube/Line). 2D map, so
/// four options — no diagonals. See Doc 12 §Open Questions #2.
enum GridDirection { north, south, east, west }
