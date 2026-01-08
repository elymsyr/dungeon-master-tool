name: Build and Release

on:
  release:
    types: [created]

permissions:
  contents: write

jobs:
  build:
    runs-on: ${{ matrix.os }}
    # Emojilerin Windows terminalinde çökmemesi için global UTF-8 ayarı
    env:
      PYTHONUTF8: 1
    strategy:
      matrix:
        os: [ubuntu-20.04, windows-latest]
    # ... (Geri kalan adımlar aynı kalacak)