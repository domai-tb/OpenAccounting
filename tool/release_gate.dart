import 'dart:io';

import 'package:path/path.dart' as p;

Future<ProcessResult> runAnalyzerGate({String? target, String? workingDirectory}) async {
  final String directory = workingDirectory ?? Directory.current.path;
  final List<String> arguments = <String>['flutter', 'analyze', '--fatal-infos'];
  if (target != null) {
    arguments.add(target);
  }
  final ProcessResult result = await Process.run('fvm', arguments, workingDirectory: directory, runInShell: true);
  if (target == null) return result;

  final String absoluteTarget = p.normalize(p.isAbsolute(target) ? target : p.join(directory, target));
  final String relativeTarget = p.relative(absoluteTarget, from: directory);
  if (relativeTarget == '.') return result;

  return ProcessResult(
    result.pid,
    result.exitCode,
    '${result.stdout}'.replaceAll(relativeTarget, absoluteTarget),
    '${result.stderr}'.replaceAll(relativeTarget, absoluteTarget),
  );
}

Future<void> main(List<String> args) async {
  if (args.length > 1) {
    stderr.writeln('Usage: fvm dart run tool/release_gate.dart [path]');
    exitCode = 64;
    return;
  }

  final ProcessResult result = await runAnalyzerGate(target: args.isEmpty ? null : args.single);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exitCode = result.exitCode;
}
