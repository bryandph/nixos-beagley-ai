{
  runCommand,
  bash,
}:
runCommand "beagley-ai-sd-identity-guard" {nativeBuildInputs = [bash];} ''
  bash ${./sd-identity-check.sh} ${./sd-identity-guard.sh}
  mkdir "$out"
''
