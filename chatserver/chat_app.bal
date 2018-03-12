package chatserver;

import ballerina.io;
import ballerina.net.ws;


@ws:configuration {
    basePath:"/chat/{name}",
    port:9090
}
service<ws> ChatApp {
    // In-memory map to store web socket connections
    map consMap = {};

    // This resource will trigger when a new web socket connection is open
    resource onOpen (ws:Connection conn, string name) {
        // Add the new connection to the connection map
        consMap[conn.getID()] = conn;
        // Get the query parameters and path parameters to send greeting message
        map params = conn.getQueryParams();
        var age, err = (string)params.age;
        string msg;
        if (err == null) {
            msg = string `{{name}} with age {{age}} connected to chat`;
        } else {
            msg = string `{{name}} connected to chat`;
        }
        // Broadcast the "new user connected" message to existing connections
        broadcast(consMap, msg);
    }

    // This resource wil trigger when a new text message arrives to the server
    resource onTextMessage (ws:Connection con, ws:TextFrame frame, string name) {
        // Create the message
        string msg = string `{{name}}: {{frame.text}}`;
        io:println(msg);
        // Broadcast the message to existing connections
        broadcast(consMap, msg);
    }

    // This resource will trigger when a existing connection closed
    resource onClose (ws:Connection con, ws:CloseFrame frame, string name) {
        // Create the client left message
        string msg = string `{{name}} left the chat`;
        // Remove the connection from the connection map
        consMap.remove(con.getID());
        // Broadcast the client left message to existing connections
        broadcast(consMap, msg);
    }
}

// Custom function to send the test to all connections in the connection map
function broadcast (map consMap, string text) {
    // Iterate through all available connections in the connections map
    foreach wsConnection in consMap {
        var con, _ = (ws:Connection)wsConnection;
        // Send the text message to the connection
        con.pushText(text);
    }
}