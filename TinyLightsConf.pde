import processing.serial.*;
import controlP5.*;
import java.util.Map;
 
ControlP5 controlP5;
ColorWheel colorWheel;
DropdownList serialPortsDropdown;

Button connectButton, saveButton;

String serialPort = "";
String[] serialPorts = {};

Boolean connected = false;

int numLedLights = 0;
int numLedLightsCreate = -1;
int currentLedLightIndex = -1;

String arduinoVendor = "1a86";
Serial serialConnection = null;
ArrayList<Bang> ledLights = new ArrayList<Bang>();

void setup() {
  size(490, 290);
  
  controlP5 = new ControlP5(this);
  
  colorWheel = controlP5
    .addColorWheel("colorPicker", 270, 60, 200)
    .setLabel("Choose your color")
    .setRGB(color(128, 0, 255));

  String[] ports = Serial.list();
   
  for (int i=0; i < ports.length; i++) {
    Map<String, String> props = Serial.getProperties(ports[i]);
    print(ports[i]+": ");
    
    if(System.getProperty("os.name").equals("Linux")) {
      String idVendor = props.get("idVendor");
      if(idVendor != null && idVendor.equals(arduinoVendor)) {
        serialPorts = append(serialPorts, ports[i]);
      }
    } else {
      serialPorts = append(serialPorts, ports[i]);
    }
  }
  
  serialPortsDropdown = controlP5
    .addDropdownList("serialPortsDropdown")
    .setLabel("Serialport")
    .setPosition(20, 60)
    .setBarHeight(20)
    .setItemHeight(20)
    .addItems(serialPorts)
    .close();
    
  connectButton = controlP5
    .addButton("connectButton")
    .setLabel("Connect")
    .setPosition(130, 60);
     
  saveButton = controlP5
    .addButton("saveButton")
    .setLabel("Save to Flash")
    .setVisible(false)
    .setPosition(20, 240);   

}

String[] parseFrame(String frame) {
  int beginIndex = frame.indexOf(">");
  
  if(beginIndex == -1) {
    return null;
  }
  
  String rawFrame = frame.substring(beginIndex + 1);
  return split(rawFrame, ",");
}

String buildFrame(String[] arguments) {
  return ">" + join(arguments, ",") + "\n";
}

void draw () {
  background(60);

  textSize(16);
  text("TinyLights Configuration", 20, 30);
  
  if(numLedLightsCreate > -1) {
    int tmp = numLedLightsCreate;
    createLedLights(numLedLightsCreate);
    numLedLightsCreate = -1;
  }
}

void createLedLights(int num) {
  
  currentLedLightIndex = -1;
  
  for(int i = 0; i < numLedLights; i++) {
    controlP5.remove("ledLight-" + i);
    numLedLights--;
  }
  
  for(int i = 0; i < num; i++) {
    
    int y = 100 + (40 * (i / 4));
    int x = 20  + (60 * (i % 4));
    
    Bang tmp = controlP5
      .addBang("ledLight-" + i)
      .setPosition(x, y)
      .setLabel("LED " + i)
      .setValue(i);
  }
  
  for(int i = 0; i < num; i++) {
    String frame = buildFrame(new String[]{"GET", str(i) });
    serialConnection.write(frame);
  }
  
  numLedLights = num;
  
  saveButton.setVisible(true);
}

void controlEvent(ControlEvent event) {
  
  println(event.getValue());
  println(event.getName());
  
  String eventName = event.getName();
  
  if(eventName == "colorPicker") {
      if(currentLedLightIndex > -1 && currentLedLightIndex < numLedLights) {
        controlP5
          .getController("ledLight-" + currentLedLightIndex)
          .setColorForeground((int) colorWheel.getValue());
          
        String frame = buildFrame(new String[]{"SET", str(currentLedLightIndex), str(colorWheel.r()), str(colorWheel.g()), str(colorWheel.b())});
        serialConnection.write(frame);
      }
      
  } else if(eventName == "serialPortsDropdown") {
    serialPort = serialPorts[(int) event.getValue()];
    
  } else if(eventName.startsWith("ledLight")) {
    currentLedLightIndex = (int) event.getValue();
    
    if(currentLedLightIndex > -1 && currentLedLightIndex < numLedLights) {
        controlP5
          .getController("ledLight-" + currentLedLightIndex)
          .setColorForeground((int) colorWheel.getValue());
          
        String frame = buildFrame(new String[]{"SET", str(currentLedLightIndex), str(colorWheel.r()), str(colorWheel.g()), str(colorWheel.b())});
        serialConnection.write(frame);
    }
    
  } else if(eventName == "connectButton") {
      int ledCount = 0;

      if(connected) {     
        saveButton.setVisible(false);
        connectButton.setLabel("Connect");
        connected = false;
        
      } else {
        
        try {
          if(serialPort != "") {
            serialConnection = new Serial(this, serialPort, 115200);  
            serialConnection.clear();
            serialConnection.bufferUntil('\n'); 
          }
        } catch (Exception e) {
          println(e);
        }
      }
          
  } else if(eventName == "saveButton") {
      String frame = buildFrame(new String[]{"FLASH"});
      serialConnection.write(frame);
  }
}

void serialEvent(Serial serialDevice) {

  try {
    String buffer = serialDevice.readStringUntil('\n');
    if(buffer == null) {
      return;
    }
    
    String[] args = parseFrame(trim(buffer));
    if(args == null) {
      println("Failed to parse incoming frame");
      return;
    }
    
    if(args.length > 0) {
      if(args[0].equals("GET") && args.length == 5) {
        
        int index = int(args[1]);
        if(index < numLedLights) {
          controlP5
            .getController("ledLight-" + index)
            .setColorForeground(color(int(args[2]), int(args[3]), int(args[4])));
        }
      } else if(args[0].equals("NUM") && args.length == 2) {
          numLedLightsCreate = int(args[1]);
      } else if(args[0].equals("HI")) {
        String frame = buildFrame(new String[]{"NUM"});
        serialConnection.write(frame);   
      } else if(args[0].equals("OK")) {
        println("ACK");
      }
    }
  } catch(Exception e) {
    print(e);
  }
}