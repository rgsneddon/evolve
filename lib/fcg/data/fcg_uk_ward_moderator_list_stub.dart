/// Stub registry for CI/public clones without the private generated ward list.
///
/// Run `scripts/generate_uk_ward_moderators.ps1` locally to build the full
/// ONS May 2025 whitelist (gitignored).
const Set<String> fcgUkWardModeratorUsernames = {
  'mod_ainsdale',
  'e05000932',
  'mod_birkdale',
  'e05000933',
};

const Map<String, String> fcgUkWardModeratorWardNames = {
  'mod_ainsdale': 'Ainsdale',
  'e05000932': 'Ainsdale',
  'mod_birkdale': 'Birkdale',
  'e05000933': 'Birkdale',
};