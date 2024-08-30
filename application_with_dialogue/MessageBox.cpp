#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QPushButton>
#include <QVBoxLayout>
#include <QSettings>
#include <QFile>
#include <QTextStream>
#include <QDebug>
#include <QDesktopWidget>
#include <QMessageBox>
#include <QIcon>
#include <QFileInfo>
#include <QCoreApplication>

class MessageDialog : public QWidget {
public:
    MessageDialog(const QString& iniFilePath, QWidget *parent = nullptr) : QWidget(parent) {
        // Load settings
        QSettings settings(iniFilePath, QSettings::IniFormat);

        // Get the window properties
        int width = settings.value("Window/Width", 640).toInt();
        int height = settings.value("Window/Height", 480).toInt();
        QString fontName = settings.value("Window/FontName", "Arial").toString();
        int fontSize = settings.value("Window/FontSize", 24).toInt();
        QString justify = settings.value("Window/Justify", "center").toString().toLower();
        QString windowBg = settings.value("Window/WindowBackground", "white").toString();
        QString buttonBg = settings.value("Window/ButtonBackground", "lightgrey").toString();

        // Set up the dialog
        setWindowTitle(settings.value("Title/Title", "Title").toString());
        setFixedSize(width, height);
        setStyleSheet(QString("background-color: %1;").arg(windowBg));

        QVBoxLayout *layout = new QVBoxLayout(this);

        // Load messages and colors
        QStringList messages;
        QStringList colors;
        int index = 1;
        while (true) {
            QString key = QString("Messages/message%1").arg(index);
            QString message = settings.value(key).toString();
            if (message.isEmpty())
                break;
            messages.append(message);
            
            QString colorKey = QString("MessageColors/MessageColor%1").arg(index);
            QString color = settings.value(colorKey, "black").toString();
            colors.append(color);
            
            index++;
        }

        // Create labels for each message
        for (int i = 0; i < messages.size(); ++i) {
            QLabel *label = new QLabel(messages[i], this);
            label->setStyleSheet(QString("color: %1;").arg(colors[i]));
            label->setFont(QFont(fontName, fontSize));
            label->setWordWrap(true);
            if (justify == "left") {
                label->setAlignment(Qt::AlignLeft | Qt::AlignVCenter);
            } else if (justify == "right") {
                label->setAlignment(Qt::AlignRight | Qt::AlignVCenter);
            } else {
                label->setAlignment(Qt::AlignCenter);
            }
            layout->addWidget(label);
        }

        // Create OK button
        QPushButton *okButton = new QPushButton("OK", this);
        okButton->setStyleSheet(QString("background-color: %1;").arg(buttonBg));
        okButton->setFont(QFont("Arial", 14));
        connect(okButton, &QPushButton::clicked, this, &QWidget::close);
        layout->addWidget(okButton);

        // Center the window on the screen
        QDesktopWidget *desktop = QApplication::desktop();
        QRect screenRect = desktop->screenGeometry();
        move((screenRect.width() - width) / 2, (screenRect.height() - height) / 2);

        // Set the window to be always on top
        setWindowFlags(windowFlags() | Qt::WindowStaysOnTopHint);
    }
};

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    QString exePath = QCoreApplication::applicationDirPath();
    QString baseName = QFileInfo(QCoreApplication::applicationDirPath()).baseName();
    QString iniFilePath = exePath + "/" + baseName + "_params.ini";

    QFile iconFile(exePath + "/MessageBox.ico");
    if (iconFile.exists()) {
        app.setWindowIcon(QIcon(exePath + "/MessageBox.ico"));
    }

    MessageDialog dialog(iniFilePath);
    dialog.show();

    return app.exec();
}