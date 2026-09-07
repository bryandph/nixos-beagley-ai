let
  base = "https://software-dl.ti.com/jacinto7/esd/tidl-tools/11_02_16_00";
in {
  version = "11.02.16.00";
  tools = {
    url = "${base}/TIDL_TOOLS/J722S/tidl_tools.tar.gz";
    hash = "sha256-mPuzEX2lh3Kms/oGbX+6OZK50Lsbr9kGaHed8Ui4zYA=";
  };
  onnx = {
    url = "${base}/OSRT_TOOLS/X86_64_LINUX/UBUNTU_22_04/onnxruntime_tidl-1.23.0-cp310-cp310-linux_x86_64.whl";
    hash = "sha256-fxJU/g/aDxIo2lAQiOibJ7eO4S4+fHhDPkcJwIEnGus=";
  };
  tflite = {
    url = "${base}/OSRT_TOOLS/X86_64_LINUX/UBUNTU_22_04/tflite_runtime-2.12.0-cp310-cp310-linux_x86_64.whl";
    hash = "sha256-WQeF/w7Uzy5PWjbqE076YBRwBYStVea6EzM6HQdE/ek=";
  };
  model = {
    url = "https://software-dl.ti.com/jacinto7/esd/modelzoo/11_02_00/modelartifacts/AM67A/8bits/cl-6360_onnxrt_imagenet1k_fbr-pycls_regnetx-200mf_onnx.tar.gz";
    hash = "sha256-h40GFJYbKQES7KeFxdf01OfDDsd7N4+NtXMvt6JfMS0=";
    version = "11.02.00";
  };
  compilerScript = {
    url = "https://raw.githubusercontent.com/TexasInstruments-Sandbox/ti-edgeai-armbian-build/be3a57d2760691f6b4f5cc7cae6e00ccddef7016/scripts/compile-j722s-tidl-model.py";
    hash = "sha256-D2NhjLtYPhuVDmMvXc99AOeYtaSgN3XEsQdCSs9AQn8=";
  };
  downloadReference = {
    repository = "TexasInstruments/edgeai-gst-apps";
    rev = "464f70b2e780bbaed8ab048b4b548f54b75b1661";
    path = "download_models.sh";
  };
  reference = {
    repository = "TexasInstruments-Sandbox/ti-edgeai-armbian-build";
    rev = "be3a57d2760691f6b4f5cc7cae6e00ccddef7016";
    path = "scripts/compile-j722s-tidl-model.py";
  };
}
