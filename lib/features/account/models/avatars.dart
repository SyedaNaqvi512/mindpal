/// Gender values exactly as the server stores them.
class Gender {
  static const female = 'female';
  static const male = 'male';
  static const unspecified = 'unspecified';
  static const all = [female, male, unspecified];

  static String label(String g) => switch (g) {
        female => 'Female',
        male => 'Male',
        _ => 'Prefer not to say',
      };
}

/// Which predefined avatars a gender may pick (same rule as the server):
/// 1-5 female, 6-10 male, "prefer not to say" sees all ten.
class Avatars {
  static const int femaleStart = 1, femaleEnd = 5, maleStart = 6, maleEnd = 10;

  static List<int> idsFor(String gender) {
    switch (gender) {
      case Gender.female:
        return [for (var i = femaleStart; i <= femaleEnd; i++) i];
      case Gender.male:
        return [for (var i = maleStart; i <= maleEnd; i++) i];
      default:
        return [for (var i = femaleStart; i <= maleEnd; i++) i];
    }
  }

  static bool isAllowed(String gender, int id) => idsFor(gender).contains(id);

  static int defaultFor(String gender) =>
      gender == Gender.male ? maleStart : femaleStart;

  static String assetFor(int id) =>
    'assets/avatars/avatar_${id.toString().padLeft(2, "0")}.png';
}
