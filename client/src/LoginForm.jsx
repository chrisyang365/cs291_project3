import React, { useState } from "react";
import "./LoginForm.css"

function LoginForm(props) {
    const [chatURL, setChatURL] = useState('');
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');

    function login() {
        var request = new XMLHttpRequest();
        var form = new FormData();
        form.append("password", password);
        form.append("username", username);
        request.open("POST", chatURL + "/login");
        request.onreadystatechange = function() {
            if (this.readyState != 4) return;
            if (this.status === 201) {
                props.setShowModal(false)
                const data = JSON.parse(this.responseText);
                const messageToken = data.message_token;
                const streamToken = data.stream_token;
                props.setStatus('connected');
                // props.startStream(chatURL, messageToken, streamToken);
                props.setMessageToken(messageToken);
                props.setStreamToken(streamToken);
                props.setChatURL(chatURL);
            } else if (this.status === 403) {
                alert("Invalid username or password");
            } else if (this.status === 409) {
                alert(username.value + " is already logged in");
            } else {
                alert(this.status + " failure to /login");
            }
        };
        request.send(form);
    }

    return(
        <div>
            <div id="login-modal" >
                <div className="content">
                    <h2>Login</h2>
                    <div>
                        <label>Chat URL <br /><input id="url" type="text" value={chatURL} onChange={(e) => setChatURL(e.target.value)}/></label>
                    </div>
                    <div>
                        <label>Username <br /><input id="username" type="text" value={username} onChange={(e) => setUsername(e.target.value)}/></label>
                    </div>
                    <div>
                        <label>Password <br /><input id="password" type="password" value={password} onChange={(e) => setPassword(e.target.value)}/></label>
                    </div>
                    <div>
                        <button type="submit" disabled={!(chatURL && username && password)} onClick={login}>Login</button>
                    </div>
                </div>
            </div>
        </div>
    )
}

export default LoginForm;