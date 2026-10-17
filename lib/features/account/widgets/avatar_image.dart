
import 'package:flutter/material.dart';

import '../models/avatars.dart';

class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.avatarId, this.size = 48});

  final int avatarId;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        Avatars.assetFor(avatarId),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.person, size: size * 0.6),
        ),
      ),
    );
  }
}
