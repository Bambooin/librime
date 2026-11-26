#!/bin/bash
set -e

llvm_major="$(make -s llvm-major-version)"

# https://apt.llvm.org/
curl -fsSL https://apt.llvm.org/llvm.sh -o llvm.sh
chmod +x llvm.sh

sudo ./llvm.sh "$llvm_major"
sudo apt install -y clang-format-"$llvm_major" clang-tidy-"$llvm_major"
rm -f llvm.sh

for tool in clang-format clang-tidy run-clang-tidy clang-apply-replacements; do
  sudo update-alternatives --install /usr/bin/"$tool" "$tool" /usr/bin/"$tool"-"$llvm_major" 100
  sudo update-alternatives --set "$tool" /usr/bin/"$tool"-"$llvm_major"
done
