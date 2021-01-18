import 'dart:async';
import 'dart:convert';
import 'dart:io';

Timer timer;
var client = HttpClient();
var latestId = 0;
var idFile = File(Platform.environment['IDFILEPATH']);
var apkFile = File(Platform.environment['APKFILEPATH']);
void main() async
{
  var id = (await idFile.exists()) ? await idFile.readAsString() : null;
  if(id != null && id.isNotEmpty)
  {
    latestId = int.parse(id);
  }

  if(!await apkFile.exists())
  {
    await apkFile.create();
  }

  if(!await idFile.exists())
  {
    await idFile.create();
  }

  await test(null);
  timer = Timer.periodic(Duration(hours: 1), test);
}

Future test(Timer timer) async
{
  Map<String, dynamic> latestRelease = await fetchJSON(Uri(scheme: 'https', host: 'api.github.com', path: 'repositories/${Platform.environment["REPO"]}/releases/latest'));
  if(latestId != latestRelease['id'])
  {
    print('id missmatch');
    latestId = latestRelease['id'];
    var apk = await fetchApk(Uri.parse(latestRelease['assets'][0]['browser_download_url']));
    print('download finished');
    await apkFile.writeAsBytes(apk);
    await idFile.writeAsString(latestId.toString());
    print('file writing is done');
  }
  print('nothing else to do');
}

Future<dynamic> fetchJSON(Uri url) async
{
  var request = await client.getUrl(url);
  var response = await request.close();
  var list = await response.transform(Utf8Decoder()).toList();
  var body = list.fold('', (previousValue, element) => previousValue + element);
  return json.decode(body);
}

Future<List<int>> fetchApk(Uri url) async
{
  var request = await client.getUrl(url);
  var response = await request.close();
  var body =
  await response.fold(<int>[], (List<int> previous, element) {previous.addAll(element); return previous;});
  return body;
}
