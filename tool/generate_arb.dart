// ... existing code ...
import 'dart:convert';
import 'dart:io';

void main() async {
  final sourcePath = 'lib/l10n/app_en_ZA.arb';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Source ARB not found at $sourcePath');
    exit(1);
  }

  final Map<String, dynamic> source =
      json.decode(await sourceFile.readAsString());

  // Languages: Afrikaans, isiZulu, isiXhosa, isiNdebele, Sepedi, Sesotho,
  // Setswana, siSwati, Tshivenda, Xitsonga
  final targets = <String, String>{
    'af': 'lib/l10n/app_af.arb',
    'zu': 'lib/l10n/app_zu.arb',
    'xh': 'lib/l10n/app_xh.arb',
    'nr': 'lib/l10n/app_nr.arb',
    'nso': 'lib/l10n/app_nso.arb',
    'st': 'lib/l10n/app_st.arb',
    'tn': 'lib/l10n/app_tn.arb',
    'ss': 'lib/l10n/app_ss.arb',
    've': 'lib/l10n/app_ve.arb',
    'ts': 'lib/l10n/app_ts.arb',
  };

  for (final entry in targets.entries) {
    final locale = entry.key;
    final path = entry.value;

    // Clone keys, but ensure @@locale is the target language code
    final Map<String, dynamic> clone = Map<String, dynamic>.from(source);
    clone['@@locale'] = locale;

    // Optional: strip English metadata from non-English files
    // Keep only keys without @-metadata except @@locale
    clone.removeWhere((k, _) => k.startsWith('@') && k != '@@locale');

    // Ensure target directory exists
    final targetFile = File(path);
    targetFile.parent.createSync(recursive: true);

    await targetFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(clone),
    );

    stdout.writeln('Generated $path');
  }

  stdout.writeln('Done. Translate values in generated ARBs as needed.');
}
// ... existing code ...