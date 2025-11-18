#include <WiFi.h> 
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <IRremote.hpp>

// ---------------- IR ----------------
#define IR_SEND_PIN 4
#define IR_RECV_PIN 14

bool toggleBit = false;   // <===== NECESARIO PARA RC5



// ---------------- MQTT ----------------
const char* mqtt_server = "pbbc16fc.ala.us-east-1.emqxsl.com";
const int mqtt_port = 8883;
const char* mqtt_user = "IOT";
const char* mqtt_pass = "Domotica123";

// ---------------- TOPICOS ----------------
const char* topic_tv   = "casa/Televisor";
const char* topic_fan  = "casa/Ventilador";
const char* topic_fridge = "casa/Heladera";


// ---------------- TABLA COMANDOS RC5 ----------------
struct RC5cmd {
  const char* name;
  uint8_t address;
  uint8_t command;
};


RC5cmd rc5cmds[] = {
  {"power",     0x00, 0x0C},
  {"vol_up",    0x00, 0x10},
  {"vol_down",  0x00, 0x11},
  {"ch_up",     0x00, 0x20},
  {"ch_down",   0x00, 0x21},
};

// ---------------- TABLA NEC (VENTILADOR) ----------------
struct IRCommandNEC {
  const char* name;
  uint32_t code;
  uint8_t bits;
};

IRCommandNEC necCmds[] = {
  
};

WiFiClientSecure espClient;
PubSubClient client(espClient);

// ---------------- ENVIAR RC5 (CORRECTO PARA IRREMOTE 4.5.0) ----------------
void irSendCommand(const char* cmd) {
  for (auto &c : rc5cmds) {
    if (strcmp(cmd, c.name) == 0) {

      toggleBit = !toggleBit;  // <===== FUNDAMENTAL PARA RC5

      IrSender.sendRC5(c.address, c.command, toggleBit);

      Serial.printf("IR RC5 enviado: %s  Addr=0x%02X Cmd=0x%02X Toggle=%d\n",
                      cmd, c.address, c.command, toggleBit);
    }
  }
}

// ---------------- ENVIAR NEC ----------------
void irSendNEC(const char* cmd) {
  for (auto &c : necCmds) {
     {
      IrSender.sendNEC(c.code, c.bits);
      Serial.printf("IR NEC enviado: %s\n", cmd);
    }
  }
}



// ---------------- MQTT CALLBACK ----------------
void callback(char* topic, byte* payload, unsigned int length) {
  payload[length] = 0;
  String msg = String((char*)payload);

  Serial.println("-----------------------------");
  Serial.print("TOPIC: "); Serial.println(topic);
  Serial.print("MSG: "); Serial.println(msg);

  // ======== TELEVISOR ========
  if (String(topic) == topic_tv) {

    if (msg == "encender")  irSendCommand("power");
    if (msg == "apagar")    irSendCommand("power");
    if (msg == "vol_up")    irSendCommand("vol_up");
    if (msg == "vol_down")  irSendCommand("vol_down");
    if (msg == "ch_up")     irSendCommand("ch_up");
    if (msg == "ch_down")   irSendCommand("ch_down");

    return;
  }

  // ======== VENTILADOR ========
  if (String(topic) == topic_fan) {
    if (msg == "power") irSendNEC("fan_power");
    return;
  }

  // ======== HELADERA ========
  if (String(topic) == topic_fridge) {
    Serial.println("Heladera comando: " + msg);
    return;
  }
}





// ---------------- SETUP ----------------
void setup() {
  Serial.begin(115200);

  IrReceiver.begin(IR_RECV_PIN);
  IrSender.begin(IR_SEND_PIN);

  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  while (WiFi.status() != WL_CONNECTED) delay(500);

  espClient.setInsecure();
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);

  Serial.println("ESP32 listo.");
}



// ---------------- LOOP ----------------
void loop() {
  if (!client.connected()) reconnectMQTT();
  client.loop();
}
