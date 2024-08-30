using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Linq;

namespace MessageBoxApp
{
    public partial class Form1 : Form
    {
        private List<string> messages;
        private List<Color> colors;

        public Form1()
        {
            InitializeComponent();
            LoadSettings();
        }

        private void LoadSettings()
        {
            string exePath = Path.GetDirectoryName(Application.ExecutablePath);
            string baseName = Path.GetFileNameWithoutExtension(Application.ExecutablePath);
            string iniFilePath = Path.Combine(exePath, $"{baseName}_params.ini");

            if (!File.Exists(iniFilePath))
            {
                MessageBox.Show($"The file '{iniFilePath}' does not exist.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
                return;
            }

            var config = new IniFile(iniFilePath);
            string title = config.Read("Title", "Title");
            int width = int.TryParse(config.Read("Window", "Width"), out var w) ? w : 640;
            int height = int.TryParse(config.Read("Window", "Height"), out var h) ? h : 480;
            string fontName = config.Read("Window", "FontName", "Arial");
            int fontSize = int.TryParse(config.Read("Window", "FontSize"), out var fs) ? fs : 24;
            string justify = config.Read("Window", "Justify", "center");
            string windowBg = config.Read("Window", "WindowBackground", "white");
            string buttonBg = config.Read("Window", "ButtonBackground", "lightgrey");

            Text = title;
            Width = width;
            Height = height;
            BackColor = Color.FromName(windowBg);
            Font = new Font(fontName, fontSize);

            // Set up messages and colors
            messages = new List<string>();
            colors = new List<Color>();
            int index = 1;
            while (true)
            {
                string message = config.Read("Messages", $"message{index}");
                if (string.IsNullOrEmpty(message)) break;
                messages.Add(message);

                string colorStr = config.Read("MessageColors", $"MessageColor{index}", "black");
                colors.Add(Color.FromName(colorStr));
                index++;
            }

            // Add labels for messages
            int y = 10;
            foreach (var message in messages.Select((msg, idx) => new { msg, idx }))
            {
                var label = new Label
                {
                    Text = message.msg,
                    ForeColor = colors[message.idx],
                    BackColor = Color.FromName(windowBg),
                    AutoSize = true,
                    Location = new Point(10, y)
                };
                label.TextAlign = justify switch
                {
                    "left" => ContentAlignment.MiddleLeft,
                    "right" => ContentAlignment.MiddleRight,
                    _ => ContentAlignment.MiddleCenter
                };
                Controls.Add(label);
                y += label.Height + 10;
            }

            // Add OK button
            var okButton = new Button
            {
                Text = "OK",
                BackColor = Color.FromName(buttonBg),
                ForeColor = Color.Black,
                Font = new Font("Arial", 14),
                Width = 100,
                Height = 40,
                Location = new Point((width - 100) / 2, height - 60)
            };
            okButton.Click += (sender, args) => Close();
            Controls.Add(okButton);

            // Center the window on the screen
            StartPosition = FormStartPosition.CenterScreen;
            TopMost = true;
            AcceptButton = okButton;
        }
    }

    public class IniFile
    {
        private readonly string path;

        public IniFile(string path)
        {
            this.path = path;
        }

        public string Read(string section, string key, string defaultValue = "")
        {
            var buffer = new System.Text.StringBuilder(255);
            GetPrivateProfileString(section, key, defaultValue, buffer, buffer.Capacity, path);
            return buffer.ToString();
        }

        [System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
        private static extern int GetPrivateProfileString(string section, string key, string defaultValue, System.Text.StringBuilder buffer, int size, string filePath);
    }
}