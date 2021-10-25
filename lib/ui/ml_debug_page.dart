import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:photos/services/ml_service.dart';

class MLDebugPage extends StatefulWidget {
  MLDebugPage({Key key}) : super(key: key);

  @override
  _MLDebugPageState createState() => _MLDebugPageState();
}

class _MLDebugPageState extends State<MLDebugPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Hero(
          tag: "mldebug",
          child: Material(
            type: MaterialType.transparency,
            child: Text(
              "ML Debug",
              style: TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      ),
      body: _getBody(),
    );
  }

  Widget _getBody() {
    return FutureBuilder<Map<int, List<imglib.Image>>>(
      future: MLService.instance
          .getFaceWithLabels(), // function where you call your api
      builder: (BuildContext context,
          AsyncSnapshot<Map<int, List<imglib.Image>>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: Text('Please wait its loading...'));
        } else {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final vertWidgets = snapshot.data.values.map((faces) {
              final horiWidgets = faces.map((faceImg) {
                return Image.memory(imglib.encodeJpg(faceImg));
              });
              return Container(
                  width: double.infinity,
                  height: 120,
                  child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: List.from(horiWidgets)));
            });

            final vertList = ListView(
                scrollDirection: Axis.vertical,
                children: List.from(vertWidgets));

            return Container(
              width: double.infinity,
              height: 1000.0,
              child: vertList,
            );
          }
        }
      },
    );
  }
}
