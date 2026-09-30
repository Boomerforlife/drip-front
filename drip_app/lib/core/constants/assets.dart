/// Asset paths. Photos were exported from the Figma file; icons are the
/// Figma vector paths exported as SVG.
abstract final class Assets {
  static String image(String name) => 'assets/images/$name.jpg';

  static const navSparkles = 'assets/icons/nav_sparkles.svg';
  static const navSearch = 'assets/icons/nav_search.svg';
  static const navPlus = 'assets/icons/nav_plus.svg';
  static const navBriefcase = 'assets/icons/nav_briefcase.svg';
  static const navUser = 'assets/icons/nav_user.svg';
  static const navStudio = 'assets/icons/nav_studio.svg';
}
