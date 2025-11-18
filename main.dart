import 'package:flutter/material.dart';
import 'mqtt_service.dart';
import 'dart:async';




void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  mqtt = MQTTService();
  await mqtt.connect(); // intento inicial de conexión
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Store Impression · Domótica',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.cyanAccent,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
      ),
      home: const ControlPage(),
    );
  }
}

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}


class _ControlPageState extends State<ControlPage> {
  final List<DeviceState> devices = [
    DeviceState(name: 'televisor', volume: 5, channel: 1),
    DeviceState(name: 'ventilador', mode: 'Bajo'),
    DeviceState(name: 'heladera'),
  ];

  bool mqttReady = false;

  @override
  void initState() {
    super.initState();
    mqttReady = mqtt.isConnected;
    // escuchamos mensajes de estado/copia (si el ESP publica)
    mqtt.stateStream.listen((map) {
      setState(() {
        map.forEach((device, payload) {
          final idx = devices.indexWhere((d) => d.name.toLowerCase() == device.toLowerCase());
          if (idx >= 0) {
            devices[idx].statusText = payload;
          }
        });
      });
    });
    mqtt.copyStream.listen((map) {
      setState(() {
        map.forEach((device, payload) {
          final idx = devices.indexWhere((d) => d.name.toLowerCase() == device.toLowerCase());
          if (idx >= 0) {
            devices[idx].copyText = payload;
          }
        });
      });
    });

    // polling sencillo de estado de conexión (para actualizar UI)
    Timer.periodic(const Duration(seconds: 2), (_) {
  if (!mounted) return;
  final now = mqtt.isConnected;
  if (mqttReady != now) {
    setState(() => mqttReady = now);
  }
});

  }

  // enviar comando al tópico casa/<device>
  Future<void> sendCmd(String device, String payload) async {
    final topic = 'casa/${device[0].toUpperCase()}${device.substring(1)}'; // Televisor case
    // Si tu ESP espera 'casa/televisor' en minúscula, usa:
    // final topic = 'casa/$device';
    if (!mqtt.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MQTT no conectado')));
      return;
    }
    await mqtt.sendMessage(topic, payload);
  }

  Widget deviceCard(DeviceState d) {
    final isTV = d.name == 'televisor';
    final isFan = d.name == 'ventilador';
    final isFridge = d.name == 'heladera';

    final title = d.name[0].toUpperCase() + d.name.substring(1);

    final gradient = isTV
        ? const LinearGradient(colors: [Color(0xFF123CFF), Color(0xFF00E5FF)])
        : isFan
            ? const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFFEA00)])
            : const LinearGradient(colors: [Color(0xFF2DD4BF), Color(0xFF34D399)]);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(isTV ? Icons.tv : isFan ? Icons.toys : Icons.kitchen, color: Colors.white),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              if (d.statusText.isNotEmpty) Text('Estado: ${d.statusText}', style: const TextStyle(color: Colors.white70)),
            ])
          ]),
          IconButton(
            onPressed: mqtt.isConnected ? () async {
              d.power = !d.power;
              setState(() {});
              await sendCmd(d.name, d.power ? 'encender' : 'apagar');
            } : null,
            icon: Icon(Icons.power_settings_new, color: d.power ? Colors.greenAccent : Colors.white),
          )
        ]),
        const SizedBox(height: 12),
        if (isTV) ...[
          Row(children: [
            ElevatedButton(onPressed: mqtt.isConnected && d.power ? () => sendCmd(d.name, 'vol_down') : null, child: const Text('VOL-')),
            const SizedBox(width: 8),
            Text('Vol ${d.volume}', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected && d.power ? () => sendCmd(d.name, 'vol_up') : null, child: const Text('VOL+')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton(onPressed: mqtt.isConnected && d.power ? () => sendCmd(d.name, 'ch_down') : null, child: const Text('CH-')),
            const SizedBox(width: 8),
            Text('Canal ${d.channel}', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected && d.power ? () => sendCmd(d.name, 'ch_up') : null, child: const Text('CH+')),
          ]),
        ],
        if (isFan) ...[
          Row(children: [
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'encender') : null, child: const Text('ON')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'apagar') : null, child: const Text('OFF')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'modo:Bajo') : null, child: const Text('Bajo')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'modo:Medio') : null, child: const Text('Medio')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'modo:Alto') : null, child: const Text('Alto')),
          ]),
        ],
        if (isFridge) ...[
          Row(children: [
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'encender') : null, child: const Text('ENCENDER')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: mqtt.isConnected ? () => sendCmd(d.name, 'apagar') : null, child: const Text('APAGAR')),
          ])
        ],
        if (d.copyText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Último IR: ${d.copyText}', style: const TextStyle(color: Colors.white70))
        ]
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Impression · Control'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Row(children: [
              Icon(mqtt.isConnected ? Icons.cloud_done : Icons.cloud_off, color: mqtt.isConnected ? Colors.green : Colors.red),
              const SizedBox(width: 8),
              Text(mqtt.isConnected ? 'Online' : 'Offline', style: const TextStyle(color: Colors.white70)),
            ]),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(children: [
            Expanded(child: ListView(children: devices.map((d) => deviceCard(d)).toList())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: mqtt.isConnected ? () => sendCmd('televisor', 'power') : null,
                icon: const Icon(Icons.flash_on),
                label: const Text('Prueba Power TV'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent),
              )),
              const SizedBox(width: 12),
              ElevatedButton(onPressed: () async {
                if (!mqtt.isConnected) {
                  await mqtt.connect();
                  setState(() {});
                }
              }, child: const Icon(Icons.refresh))
            ])
          ]),
        ),
      ),
    );
  }
}
