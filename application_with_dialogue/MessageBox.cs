using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Text;

namespace MessageBoxApp
{
    public partial class Form1 : Form
    {
        private List<string> messages;
        private List<Color> colors;

        public Form1()
        {
            InitializeComponent();
            messages = new List<string>(); // Initialize
            colors = new List<Color>();   // Initialize
            LoadSettings();
        }

        private void LoadSettings()
        {   
            string exePath = Path.GetDirectoryName(Application.ExecutablePath) ?? string.Empty;
            string baseName = Path.GetFileNameWithoutExtension(Application.ExecutablePath) ?? string.Empty;
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
            int index = 1;
            while (true)
            {
                string message0 = config.Read($"Messages", $"message{index}");
                Console.WriteLine(message0);
                byte[] bytes = Encoding.Default.GetBytes(message0);
                string message = Encoding.UTF8.GetString(bytes);
                Console.WriteLine(message);
                if (string.IsNullOrEmpty(message)) break;
                // Replace \n with Environment.NewLine for correct line breaks
                messages.Add(message.Replace("\\n", Environment.NewLine));

                string colorStr = config.Read("MessageColors", $"MessageColor{index}", "black");
                colors.Add(Color.FromName(colorStr));
                index++;
            }

            // Add labels for messages
            int y = 10;
            for (int i = 0; i < messages.Count; i++)
            {
                var label = new Label
                {
                    Text = messages[i],
                    ForeColor = colors[i],
                    BackColor = Color.FromName(windowBg),
                    AutoSize = true,
                    Location = new Point(10, y),
                    MaximumSize = new Size(Width - 20, 0)
                };
                if (justify == "left")
                {
                    label.TextAlign = ContentAlignment.MiddleLeft;
                }
                else if (justify == "right")
                {
                    label.TextAlign = ContentAlignment.MiddleRight;
                }
                else
                {
                    label.TextAlign = ContentAlignment.MiddleCenter;
                }
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

        public class IniFile
        {
            private readonly string path;

            public IniFile(string path)
            {
                this.path = path;
            }

            public string Read(string section, string key, string defaultValue = "")
            {
                var buffer = new StringBuilder(255);
                GetPrivateProfileStringW(section, key, defaultValue, buffer, buffer.Capacity, path);
                return buffer.ToString();
            }

            [System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Auto)]
            private static extern int GetPrivateProfileStringW(string section, string key, string defaultValue, StringBuilder buffer, int size, string filePath);
        }
    }
}
