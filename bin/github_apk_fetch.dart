import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:git/git.dart';

import 'src/auth_token_gen.dart';
import 'src/jwt_gen.dart';

Timer timer;
final client = HttpClient();
var latestId = 0;
final idFile = File(Platform.environment['IDFILEPATH']);
final repoDir = Directory(Platform.environment['REPOFOLDER']);
final apkFile = File(Platform.environment['REPOFOLDER'] +'/'+ Platform.environment['APKFILENAME']);
final privateKey = File(Platform.environment['PRIVATEKEY']);
GitDir gitdir;
AuthTokenGen gen;
void main() async
{
  var id = (await idFile.exists()) ? await idFile.readAsString() : null;
  if(id != null && id.isNotEmpty)
  {
    latestId = int.parse(id);
  }

  var jwtgen = JWTGen(Platform.environment['APPID'],
      PrivateKey(await privateKey.readAsString()));
  
  var repofull = Platform.environment['REPONAME'];

  gen = AuthTokenGen(jwtgen, client, repofull.split('/')[0], repofull.split('/')[1]);

  if( await apkFile.exists())
  {
    gitdir = await GitDir.fromExisting(repoDir.parent.path);
    await updateFDroidRepo();
  }
  else
  {
    await initFDroidRepo();
  }

  await test(null);
  timer = Timer.periodic(Duration(hours: 1), test);
}

Future test(Timer timer) async
{
  Map<String, dynamic> latestRelease = await fetchJSON(Uri(scheme: 'https', host: 'api.github.com', path: 'repositories/${Platform.environment["REPO"]}/releases/latest'));
  if(latestId != latestRelease['id'] || !await apkFile.exists())
  {
    print('id missmatch');
    latestId = latestRelease['id'];
    var apk = await fetchApk(Uri.parse(latestRelease['assets'][0]['browser_download_url']));
    print('download finished');
    await apkFile.writeAsBytes(apk);
    await idFile.writeAsString(latestId.toString());
    print('file writing is done');
    await updateFDroidRepo();
  }
  print('nothing else to do');
}

Future<dynamic> fetchJSON(Uri url) async
{
  var request = await client.getUrl(url);
  var response = await request.close();
  var body = await response.transform(Utf8Decoder()).fold<String>('', (previousValue, element) => previousValue + element);
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

Future updateFDroidRepo() async
{
  
  await gitdir.runCommand(['pull']);

  var res = await Process.run('fdroid', ['update','-c'], workingDirectory: repoDir.parent.path, runInShell: true);
  if(res.exitCode != 0)
  {
    print(res.stderr);
    print('An error happened while we were upgrading! Check the logs!');
  }
  else
  {
    print('Update successfully!');
    var token = await gen.produce();
    await gitdir.runCommand(['add', '--all']);
    await gitdir.runCommand(['commit', '-m', 'update at ' + DateTime.now().toIso8601String()]);
    await gitdir.runCommand(['push', 'https://x-access-token:$token@github.com/' +  Platform.environment['REPONAME'],'master']);
  }
}

Future initFDroidRepo() async 
{

  if(!await GitDir.isGitDir(repoDir.parent.path))
  {
    await runGit(['clone', 'https://github.com/' + Platform.environment['REPONAME'], repoDir.parent.path]);
  }

  gitdir = await GitDir.fromExisting(repoDir.parent.path);

  if(!await repoDir.exists())
  {
    await repoDir.create();
  }

  var res = await Process.run('fdroid', ['init'], workingDirectory: repoDir.parent.path, runInShell: true);
  if(res.exitCode != 0)
  {
    print('An error happened while we were initalising! Check the logs!');
  }
  else
  {
    print('fdroid init successful!');
    var exit_code = 0;
    res = await Process.run('chmod', ['-R', 'a=rwx', 'repo'], workingDirectory: repoDir.parent.path);
    exit_code += res.exitCode;
    res = await Process.run('chmod', ['-R', 'a=rwx', 'archive'], workingDirectory: repoDir.parent.path);
    exit_code += res.exitCode;
    res = await Process.run('chmod', ['-R', 'a=rwx', 'metadata'], workingDirectory: repoDir.parent.path);
    exit_code += res.exitCode;
    exit_code == 0 ? print('Init was finished') : print('An error happened while trying to change permissions!');
  }
}
