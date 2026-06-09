import 'package:flutter/material.dart';

class MasonryGrid extends StatelessWidget {
  final int crossAxisCount;
  final double spacing;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const MasonryGrid({
    super.key,
    required this.crossAxisCount,
    required this.children,
    this.spacing = 10,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final cols = List.generate(crossAxisCount, (_) => <Widget>[]);
    for (var i = 0; i < children.length; i++) {
      cols[i % crossAxisCount].add(children[i]);
    }
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < crossAxisCount; c++) ...[
            if (c > 0) SizedBox(width: spacing),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var j = 0; j < cols[c].length; j++) ...[
                    if (j > 0) SizedBox(height: spacing),
                    cols[c][j],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
