using System;
using System.Collections.Generic;
using System.Drawing;
using System.IO;
using System.Windows.Forms;
using System.Xml.Linq;
using System.Text.RegularExpressions;
using System.Reflection;

namespace MessageBoxApp
{
    public partial class Form1 : Form
    {
        private List<string> messages;
        private List<int> msgCount;
        private List<Color> colors;

        public Form1()
        {
            InitializeComponent();
            messages = new List<string>(); // Initialize
            msgCount = new List<int>();
            colors = new List<Color>();   // Initialize
            LoadSettings();

            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            AutoSize = false;
            KeyPreview = true;

            // Set the form's icon from the embedded resource
            string resourceName = "MessageBoxApp.MessageBox.ico"; // Correct namespace and resource name
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream(resourceName))
            {
                if (stream != null)
                {
                    Icon = new Icon(stream);
                }
                else
                {
                    MessageBox.Show("Icon resource not found.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            base.OnKeyDown(e);
            if (e.KeyCode == Keys.Escape)
            {
                Close(); // Close the form when the Esc key is pressed
            }
        }

        private void LoadSettings()
        {
            string exePath = AppDomain.CurrentDomain.BaseDirectory;
            string executableName = System.Diagnostics.Process.GetCurrentProcess().ProcessName;
            string xmlFilePath = Path.Combine(exePath, $"{executableName}_params.xml");

            if (!File.Exists(xmlFilePath))
            {
                MessageBox.Show($"The file '{xmlFilePath}' does not exist.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Application.Exit();
                return;
            }

            var config = XDocument.Load(xmlFilePath);
            var root = config.Element("Configuration");

            string title = root?.Element("Title")?.Value ?? "Title";
            int width = int.TryParse(root?.Element("Window")?.Element("Width")?.Value, out var w) ? w : 640;
            int height = int.TryParse(root?.Element("Window")?.Element("Height")?.Value, out var h) ? h : 480;
            string fontName = root?.Element("Window")?.Element("FontName")?.Value ?? "Arial";
            int fontSize = int.TryParse(root?.Element("Window")?.Element("FontSize")?.Value, out var fs) ? fs : 24;
            string justify = root?.Element("Window")?.Element("Justify")?.Value ?? "center";
            string windowBg = root?.Element("Window")?.Element("WindowBackground")?.Value ?? "white";
            string buttonBg = root?.Element("Window")?.Element("ButtonBackground")?.Value ?? "lightgrey";

            Text = title;
            Width = width;
            Height = height;
            BackColor = Color.FromName(windowBg);
            Font = new Font(fontName, fontSize);

            // Set up messages and colors
            foreach (var messageElement in root?.Element("Messages")?.Elements("Message") ?? new List<XElement>())
            {
                string message1 = messageElement.Value;
                int newlineCount = Regex.Matches(message1, @"\\n").Count;
                string message = messageElement.Value.Replace("\\n", Environment.NewLine);
                string colorStr = messageElement.Attribute("color")?.Value ?? "black";
                messages.Add(message);
                msgCount.Add(newlineCount + 1);
                colors.Add(Color.FromName(colorStr));
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
                    AutoSize = false,
                    Location = new Point(10, y),
                    Width = width - 20,
                    Height = (int)(fontSize * 1.5 * msgCount[i]),
                    TextAlign = justify == "left" ? ContentAlignment.TopLeft :
                                justify == "right" ? ContentAlignment.TopRight :
                                ContentAlignment.MiddleCenter,
                };
                Controls.Add(label);
                y += label.Height + 15;
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
                Location = new Point((width - 100) / 2, height - 100)
            };
            okButton.Click += (sender, args) => Close();
            Controls.Add(okButton);

            // Center the window on the screen
            StartPosition = FormStartPosition.CenterScreen;
            TopMost = true;
            AcceptButton = okButton;
        }
    }
}
