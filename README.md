<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>تطبيق عمار ياسر لتبادل المتابعة</title>
    <style>
        body {
            font-family: Tahoma, sans-serif;
            background-color: #fafafa;
            margin: 0;
            padding: 20px;
            text-align: center;
        }
        .container {
            max-width: 400px;
            margin: 50px auto;
            background: #fff;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 10px rgba(0,0,0,0.1);
        }
        h2 {
            color: #E1306C;
        }
        input {
            width: 90%;
            padding: 10px;
            margin: 10px 0;
            border: 1px solid #dbdbdb;
            border-radius: 5px;
            font-size: 16px;
        }
        button {
            background-color: #0095f6;
            color: white;
            border: none;
            padding: 10px 20px;
            font-size: 16px;
            border-radius: 5px;
            cursor: pointer;
            width: 100%;
        }
        button:hover {
            background-color: #0081f1;
        }
        .list-container {
            margin-top: 20px;
            text-align: right;
        }
        .user-item {
            background: #efefef;
            padding: 8px;
            margin: 5px 0;
            border-radius: 5px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .user-item a {
            text-decoration: none;
            background: #3897f0;
            color: white;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 14px;
        }
    </style>
</head>
<body>

    <div class="container" id="loginBox">
        <h2>تطبيق عمار ياسر</h2>
        <p>أدخل اسم المستخدم الخاص بك على إنستغرام للبدء:</p>
        <input type="text" id="usernameInput" placeholder="مثال: username">
        <button onclick="registerUser()">دخول وتسجيل الحساب</button>
    </div>

    <div class="container" id="appBox" style="display: none;">
        <h2>مرحباً بك يا <span id="displayName"></span></h2>
        <p>قائمة الحسابات لتبادل المتابعة:</p>
        <div class="list-container" id="usersList">
            <!-- سيتم إضافة الحسابات هنا -->
        </div>
    </div>

    <script>
        // تخزين الحسابات وهمياً (لأن GitHub Pages صفحة ثابتة)
        let accounts = JSON.parse(localStorage.getItem('insta_accounts')) || [
            "ammar_yasser_1",
            "insta_user_demo",
            "social_boost_99"
        ];

        function registerUser() {
            let username = document.getElementById('usernameInput').value.trim();
            if(username === "") {
                alert("الرجاء إدخال اسم المستخدم بشكل صحيح");
                return;
            }

            // إضافة الحساب للقائمة إذا لم يكن موجوداً
            if(!accounts.includes(username)) {
                accounts.push(username);
                localStorage.setItem('insta_accounts', JSON.stringify(accounts));
            }

            // الانتقال لواجهة التطبيق
            document.getElementById('loginBox').style.display = 'none';
            document.getElementById('appBox').style.display = 'block';
            document.getElementById('displayName').innerText = username;

            loadUsers();
        }

        function loadUsers() {
            let listDiv = document.getElementById('usersList');
            listDiv.innerHTML = "";
            accounts.forEach(acc => {
                listDiv.innerHTML += `
                    <div class="user-item">
                        <span>@${acc}</span>
                        <a href="https://instagram.com/${acc}" target="_blank">متابعة</a>
                    </div>
                `;
            });
        }
    </script>

</body>
</html>
