/// Probabilitas per kelas dari forest.json hasil train_random_forest.py.
List<double> predictForest(
  Map<String, dynamic> forest,
  List<double> features,
) {
  final trees = forest['trees'] as List;
  if (trees.isEmpty || forest['features'] != features.length) {
    throw const FormatException('Bentuk fitur tidak cocok dengan forest.json');
  }
  if (features.any((value) => !value.isFinite)) {
    throw const FormatException('Fitur berisi nilai tidak valid');
  }
  final labelCount = (forest['labels'] as List).length;
  final totals = List<double>.filled(labelCount, 0);
  for (final raw in trees) {
    final tree = raw as Map<String, dynamic>;
    final f = (tree['f'] as List).cast<int>();
    final t = (tree['t'] as List).cast<num>();
    final l = (tree['l'] as List).cast<int>();
    final r = (tree['r'] as List).cast<int>();
    var node = 0;
    while (l[node] != -1) {
      node = features[f[node]] <= t[node] ? l[node] : r[node];
    }
    final probabilities = (tree['p'] as List)[node] as List;
    for (var i = 0; i < labelCount; i++) {
      totals[i] += (probabilities[i] as num).toDouble();
    }
  }
  for (var i = 0; i < labelCount; i++) {
    totals[i] /= trees.length;
  }
  return totals;
}
