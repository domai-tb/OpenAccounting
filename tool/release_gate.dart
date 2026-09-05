import 'dart:io';

Future<ProcessResult> runAnalyzerGate({String? target, String? workingDirectory}) {
  final List<String> arguments = <String>['flutter', 'analyze', '--fatal-infos'];
  if (target != null) {
    arguments.add(target);
  }
  return Process.run('fvm', arguments, workingDirectory: workingDirectory ?? Directory.current.path, runInShell: true);
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
