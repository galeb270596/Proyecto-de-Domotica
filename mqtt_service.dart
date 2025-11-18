import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';


  Stream<Map<String, String>> get stateStream => _stateController.stream;
  Stream<Map<String, String>> get copyStream => _copyController.stream;

  Future<void> connect() async {
    client = MqttServerClient(broker, 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    client.port = port;
    client.secure = true;
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.logging(on: true);

    client.securityContext = SecurityContext.defaultContext;

    final connMess = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .authenticateAs(username, password)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    client.connectionMessage = connMess;

    try {
      print('MQTT: Conectando...');
      await client.connect();
    } catch (e) {
      print('MQTT: Error → $e');
      client.disconnect();
      _isConnected = false;
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT: Conectado OK!');
      _isConnected = true;
    } else {
      print('MQTT: ERROR estado → ${client.connectionStatus}');
      client.disconnect();
      _isConnected = false;
    }

    // Escuchar mensajes si llega algo
    client.updates?.listen((messages) {
      final recMess = messages[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

      final topic = messages[0].topic;
      print("Llegó → $c : $payload");

      // ENVÍO A STREAMS SEGÚN TÓPICO
      if (topic.contains("estado")) {
        _stateContro
  }

  void onDisconnected() {
    print('MQTT: Desconectado');
    _isConnected = false;
  }
}
