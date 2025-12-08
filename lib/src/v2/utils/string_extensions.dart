extension StringExtensions on String {
  String toPascalCase() {
    return this.split('_').map((word) => word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1)).join('');
  }
}
