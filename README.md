# Protobuf for Proxyman macOS app
Protobuf for Proxyman app - Include Apple Silicon & Intel architecture

### How to build
1. Open the project on the latest Xcode -> Product menu -> Archive
2. Window -> Organizier -> Select Protobuf project -> Distribute Content -> Build Product -> Save to Desktop
3. Drag the framework to Proxyman
4. Done

### Generate desc file
- Convert all proto to one desc file
```sh
protoc --descriptor_set_out=output.desc --include_imports -I=~/Desktop/proto *.proto
```

### Verify
After archiving the build, we need to verify whether or not the framrwork is ready for M1 & Intel chip.

Run:
```bash
$ lipo -archs ~/Desktop/Protobuf/Products/Library/Frameworks/Protobuf.framework/Versions/A/Protobuf

-> x86_64 arm64
```