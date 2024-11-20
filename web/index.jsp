<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Online Web Editor</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f1f7f9;
            color: #333;
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        h2 {
            text-align: center;
            margin-top: 20px;
            color: #007bff;
        }

        .container {
            margin-top: 50px;
            display: flex;
            justify-content: center;
            align-items: flex-start;
            gap: 30px;
        }

        #textEditor, #messageSection {
            border: 1px solid #ced4da;
            border-radius: 10px;
            padding: 20px;
            background-color: #ffffff;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
        }

        #textEditor {
            width: 50%;
        }

        #roomInput, #nameInput {
            width: calc(100% - 90px);
            padding: 8px;
            font-size: 16px;
            margin-right: 10px;
            border: 1px solid #ced4da;
            border-radius: 5px;
            margin-bottom: 10px;
        }

        #joinRoomBtn {
            padding: 8px 15px;
            font-size: 16px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            background-color: #007bff;
            color: white;
            transition: background-color 0.3s;
        }

        #joinRoomBtn:hover {
            background-color: #0056b3;
        }

        #statusMessage {
            color: #28a745;
            margin: 10px 0;
        }

        #toolbar {
            display: flex;
            gap: 10px;
            margin-bottom: 10px;
        }

        #toolbar button {
            padding: 5px 10px;
            font-size: 14px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            background-color: #007bff;
            color: white;
            transition: background-color 0.3s;
        }

        #toolbar button:hover {
            background-color: #0056b3;
        }

        #sharedTextArea {
            min-height: 200px;
            border: 1px solid #ced4da;
            padding: 10px;
            font-size: 16px;
            background-color: #f8f9fa;
            overflow-y: auto;
            resize: none;
            border-radius: 5px;
        }

        #messageSection {
            width: 30%;
            min-height: 376px;
        }

        #messageArea {
            min-height: 300px;
            max-height: 250px;
            border: 1px solid #ced4da;
            border-radius: 5px;
            padding: 10px;
            overflow-y: auto;
            background-color: #f8f9fa;
            font-size: 14px;
            margin-bottom: 20px;
        }

        #messageArea p {
            background-color: #e6ffe6;
            padding: 5px 10px;
            border-radius: 5px;
            margin: 5px 0;
        }

        #messagebox {
            width: calc(100% - 100px);
            padding: 8px;
            font-size: 14px;
            border: 1px solid #ced4da;
            border-radius: 5px;
            margin-right: 10px;
        }

        #sendMessageBtn {
            padding: 8px 15px;
            font-size: 14px;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            background-color: #007bff;
            color: white;
            transition: background-color 0.3s;
        }

        #sendMessageBtn:hover {
            background-color: #0056b3;
        }
    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.4.0/jspdf.umd.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js"></script>
</head>

<body>
    <h2 id="header">Online Web Editor</h2>
    <div class="container">
        <div id="textEditor">
            <input type="text" id="nameInput" placeholder="Enter your name" />
            <input type="text" id="roomInput" placeholder="Enter room name" />
            <button id="joinRoomBtn" onclick="joinRoom()">Join Room</button>
            <div id="statusMessage"></div>

            <!-- Toolbar for formatting -->
            <div id="toolbar">
                <button onclick="formatText('bold')">Bold</button>
                <button onclick="formatText('italic')">Italic</button>
                <button onclick="formatText('underline')">Underline</button>
                <button onclick="downloadPDF()">Download PDF</button>
            </div>

            <!-- Content editable div for rich text editing -->
            <div id="sharedTextArea" contenteditable="false"></div>
        </div>

        <div id="messageSection">
            <div id="messageArea"></div>
            <input type="text" id="messagebox" placeholder="Enter your message" disabled />
            <button id="sendMessageBtn" onclick="sendMessage()" disabled>Send</button>
        </div>
    </div>

    <script>
        var ws;
        var timeout = null;

        function setupWebSocket() {
            ws = new WebSocket("ws://localhost:9000/WebEditor/ws");

            ws.onopen = function () {
                console.log("Connected to server");
                updateStatus("Connected to server");
            };

            ws.onmessage = function (event) {
                const params = new URLSearchParams(event.data);
                const messageType = params.get("type");
                const message = params.get("message");

                if (messageType === "textUpdate") {
                    document.getElementById("sharedTextArea").innerHTML = message;

                    // Set cursor to end of the text
                    const sharedTextArea = document.getElementById("sharedTextArea");
                    sharedTextArea.focus();
                    const range = document.createRange();
                    const selection = window.getSelection();
                    range.selectNodeContents(sharedTextArea);
                    range.collapse(false); // Collapse to the end
                    selection.removeAllRanges(); // Clear current selection
                    selection.addRange(range); // Set new selection

                } else if (messageType === "join" || messageType === "leave") {
                    updateStatus(message);
                } else if (messageType === "messageUpdate") {
                    var messageArea = document.getElementById("messageArea");
                    var p = document.createElement('p');
                    p.textContent = message;
                    messageArea.appendChild(p);
                    messageArea.scrollTop = messageArea.scrollHeight;
                }
            };


            ws.onerror = function (error) {
                console.error("WebSocket Error: ", error);
                updateStatus("Error connecting to the server. Please try again later.");
            };

            ws.onclose = function () {
                console.log("Disconnected from server");
                updateStatus("Disconnected from server");
            };
        }

        function updateStatus(message) {
            document.getElementById("statusMessage").innerHTML = message;
        }

        function updateServer() {
            var content = document.getElementById("sharedTextArea").innerHTML;
            if (ws && ws.readyState === WebSocket.OPEN) {
                ws.send("type=textUpdate&message=" + encodeURIComponent(content));
            }
        }

        function onTextChanged() {
            clearTimeout(timeout);
            timeout = setTimeout(updateServer, 500);
        }

        function formatText(command) {
            document.execCommand(command, false, null);
            onTextChanged();
        }

        function downloadPDF() {
            const { jsPDF } = window.jspdf;
            const doc = new jsPDF({
                unit: 'pt',
                format: 'a4'
            });

            const sharedTextArea = document.getElementById("sharedTextArea");

            // Temporarily adjust font size and border for rendering in PDF
            const originalFontSize = sharedTextArea.style.fontSize;
            const originalBackgroundColor = sharedTextArea.style.backgroundColor;
            const originalBorder = sharedTextArea.style.border;

            sharedTextArea.style.fontSize = "24px"; // Set PDF-specific font size
            sharedTextArea.style.backgroundColor = "transparent"; // hide background color for pdf
            sharedTextArea.style.border = "none";   // Hide border for PDF

            html2canvas(sharedTextArea, {
                scale: 2, // Maintain high scale for quality
            }).then(canvas => {
                const imgData = canvas.toDataURL('image/png');

                // Calculate dimensions for better PDF fit
                const pdfWidth = doc.internal.pageSize.getWidth() - 20;
                const pdfHeight = (canvas.height * pdfWidth) / canvas.width;

                doc.addImage(imgData, 'PNG', 10, 20, pdfWidth, pdfHeight);
                doc.save("content.pdf");

                // Revert font size and border after downloading
                sharedTextArea.style.fontSize = originalFontSize;
                sharedTextArea.style.backgroundColor = originalBackgroundColor;
                sharedTextArea.style.border = originalBorder;
            }).catch(err => {
                console.error('Error in html2canvas:', err);
            });
        }

        function joinRoom() {
            var nameInput = document.getElementById("nameInput").value;
            var roomInput = document.getElementById("roomInput").value;
            if (nameInput && roomInput) {
                ws.send("type=join&name=" + encodeURIComponent(nameInput) + "&room=" + encodeURIComponent(roomInput));
                document.getElementById("nameInput").disabled = true;
                document.getElementById("roomInput").disabled = true;
                document.getElementById("sharedTextArea").setAttribute("contenteditable", "true");
                document.getElementById("messagebox").disabled = false;
                document.getElementById("sendMessageBtn").disabled = false;
            } else {
                updateStatus("Please enter both a name and a room name.");
            }
        }

        function sendMessage() {
            var messageBox = document.getElementById("messagebox");
            if (messageBox.value.trim() !== "") {
                ws.send("type=messageUpdate&message=" + encodeURIComponent(messageBox.value));
                messageBox.value = "";
            }
        }


        window.onload = function () {
            setupWebSocket();
            document.getElementById("sharedTextArea").addEventListener("input", onTextChanged);
        };
    </script>
</body>

</html>
