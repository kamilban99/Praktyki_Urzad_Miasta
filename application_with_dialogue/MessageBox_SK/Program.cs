using System;
using System.Linq;
using System.Windows.Forms;
using System.Drawing;
using System.IO;
using IniParser;
using IniParser.Model;
using System.Text;
using System.Reflection;

namespace MessageBoxApp
{
    internal static class Program
    {
        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        static void Main()
        {
            //Application.EnableVisualStyles();
            //Application.SetCompatibleTextRenderingDefault(false);
            //Application.Run(new Form1());

            string executableName = GetExecutableName();
            string iniFilePath = $"{executableName}_params.ini";
            ShowDialogueFromIni(iniFilePath);

        }

        static string GetExecutableName()
        {
            return Path.GetFileNameWithoutExtension(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);
        }


        static void ShowDialogueFromIni(string iniFilePath)
        {
            if (!File.Exists(iniFilePath))
            {
                _ = MessageBox.Show($"The file '{iniFilePath}' does not exist.", "Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            var parser = new FileIniDataParser();
            

            // Wczytaj plik z kodowaniem UTF-8
            IniData config;
            using (var reader = new StreamReader(iniFilePath, Encoding.UTF8))
            {
                config = parser.ReadData(reader);
            }


            var title = config["Title"]["Title"] ?? "Title";

            var messages = config["Messages"]
                .Where(kvp => kvp.KeyName.StartsWith("Message"))
                .Select(kvp => kvp.Value.Replace("\\n", "\n"))
                .ToList();

            var messageColors = config["MessageColors"]
                .Where(kvp => kvp.KeyName.StartsWith("MessageColor"))
                .Select(kvp => kvp.Value ?? "black")
                .ToList();

            int.TryParse(config["Window"]["Width"], out int windowWidth);
            int.TryParse(config["Window"]["Height"], out int windowHeight);
            windowWidth = windowWidth > 0 ? windowWidth : 800;
            windowHeight = windowHeight > 0 ? windowHeight : 600;

            var fontName = config["Window"]["FontName"] ?? "Arial";
            int.TryParse(config["Window"]["FontSize"], out int fontSize);
            fontSize = fontSize > 0 ? fontSize : 24;

            var justify = config["Window"]["Justify"]?.ToLower() ?? "center";

            var windowBg = config["Window"]["WindowBackground"] ?? "lightgrey";
            var buttonBg = config["Window"]["ButtonBackground"] ?? "lightblue";

            Form dialog = new Form()
            {
                Text = title,
                Width = windowWidth,
                Height = windowHeight,
                BackColor = ColorTranslator.FromHtml(windowBg),
                StartPosition = FormStartPosition.CenterScreen,
                KeyPreview = true // Umożliwia obsługę klawiszy przed innymi kontrolkami
            };

            // dialog.Icon = new Icon("MessageBox.ico");


            // Uzyskanie dostępu do osadzonej ikony
            try
            {
                using (Stream iconStream = Assembly.GetExecutingAssembly().GetManifestResourceStream("MessageBox.MessageBox.ico"))
                {
                    if (iconStream != null)
                    {
                        dialog.Icon = new Icon(iconStream);
                    }
                    else
                    {
                        MessageBox.Show("Nie udało się załadować ikony. Zasób nie został znaleziony.", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    }
                }
            }
            catch (Exception ex)
            {
                MessageBox.Show($"Nie udało się załadować ikony: {ex.Message}", "Błąd", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }



            dialog.FormBorderStyle = FormBorderStyle.FixedDialog;
            dialog.MaximizeBox = false;

            // Dodanie obsługi zamykania okna dialogowego za pomocą klawisza Escape
            dialog.KeyDown += (sender, e) =>
            {
                if (e.KeyCode == Keys.Escape)
                {
                    dialog.Close();
                }
            };

            int yOffset = 10;
            for (int i = 0; i < messages.Count; i++)
            {
                var label = new Label()
                {
                    Text = messages[i],
                    Font = new Font(fontName, fontSize),
                    ForeColor = ColorTranslator.FromHtml(i < messageColors.Count ? messageColors[i] : "black"),
                    AutoSize = false,
                    MaximumSize = new Size(windowWidth - 40, 0), // Ogranicz szerokość tekstu do rozmiaru okna
                    TextAlign = justify == "left" ? ContentAlignment.TopLeft :
                                justify == "right" ? ContentAlignment.TopRight :
                                ContentAlignment.MiddleCenter,
                    Width = windowWidth - 20,
                    Location = new Point(10, yOffset)
                };

                // Obliczenie wysokości etykiety na podstawie jej zawartości
                Size preferredSize = label.GetPreferredSize(new Size(label.Width, 0));
                label.Height = preferredSize.Height;

                dialog.Controls.Add(label);
                yOffset += label.Height + 10;
            }


            var okButton = new Button()
            {
                Text = "OK",
                Width = 100,
                Height = 50,
                Font = new Font(fontName, 14, FontStyle.Bold),
                BackColor = ColorTranslator.FromHtml(buttonBg),
                Location = new Point((dialog.ClientSize.Width - 100) / 2, windowHeight - 120),
                DialogResult = DialogResult.OK
            };


            // Dodanie obsługi klawisza Escape do przycisku
            okButton.PreviewKeyDown += (sender, e) =>
            {
                if (e.KeyCode == Keys.Escape)
                {
                    dialog.Close();
                }
            };

            okButton.Click += (sender, e) => { dialog.Close(); };

            dialog.Controls.Add(okButton);

            dialog.AcceptButton = okButton;

            Application.Run(dialog);
        }

    }
}
