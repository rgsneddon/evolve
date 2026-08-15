import 'mishi_credentials.dart';

/// First-open help for a moderator. Same copy the GUI prints.
class MishiFirstRunGuide {
  const MishiFirstRunGuide({
    required this.record,
    required this.filePath,
  });

  final MishiCredentialRecord record;
  final String filePath;

  bool get needsGuide => record.username.isEmpty || record.password.isEmpty;

  bool get hasUsername => record.username.trim().isNotEmpty;

  /// The username the moderator must type — taken from the Desktop txt.
  String get usernameToUse => record.username.trim();

  String get usernameAdvice {
    if (hasUsername) {
      return 'Use this username from the Desktop txt: $usernameToUse';
    }
    return 'Open the Desktop file and type the value after username= into user>';
  }

  String get passwordAdvice {
    if (record.password.isNotEmpty) {
      return 'Password is already in the Desktop txt — type it into pass> (it is not shown here).';
    }
    return 'Type the value after password= from the same Desktop txt into pass>';
  }

  List<String> get steps => [
        '1. There is exactly one credentials file, on your Desktop: $filePath',
        '2. $usernameAdvice',
        '3. $passwordAdvice',
        '4. Press WRITE CREDENTIALS to register this Mac as your moderator station',
        '5. Open APPROVE to grant a voter one forum month + one voting epoch',
        '6. Open VOTES to see the wards that epoch drives; rpAI and CHAIN are next',
      ];

  static String template({String username = '', String password = ''}) {
    return '# MISHI setup strings — keep this file on your Desktop\n'
        '# Register with the username= line (ward slug such as mod_ainsdale or MOD_Ainsdale).\n'
        'username=$username\n'
        'password=$password\n';
  }
}
