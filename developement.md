### iOS

```bash
sudo gem install cocoapods
cd ios && pod install && cd ..
```
####  iOS Simulator missing in flutter devices
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

####  Error (Xcode): Framework not found TensorFlowLiteC
- Copy tflite package from pub.dev to pub.dartlang.org
    ```bash
     cp -r ~/.pub-cache/hosted/pub.dev/tflite_flutter-0.9.1 ~/.pub-cache/hosted/pub.dartlang.org/tflite_flutter-0.9.1
     ```
    
- Run setup.sh 
```bash
- ./setup.sh
```

- Install the pod again 
```bash
cd ios && pod install && cd ..
```


### Updating Protos
If you wish to update the protos, make the change in the central repo and **get it reviewed** to ensure you are not accidently making a breaking change.
```

cd protos/
git pull origin main
cd ..
protoc --proto_path=protos/ --dart_out=grpc:lib/generated/protos/ protos/**/*.proto 
```