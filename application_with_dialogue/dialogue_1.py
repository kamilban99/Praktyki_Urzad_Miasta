import tkinter as tk
from tkinter import simpledialog, filedialog, messagebox
import configparser

def configure_dialog():
    # Initialize the main window
    root = tk.Tk()
    root.title("Dialog Configurator")
    root.geometry("500x400")

    # Title input
    tk.Label(root, text="Dialog Title:", font=("Arial", 12)).pack(pady=5)
    title_entry = tk.Entry(root, font=("Arial", 12))
    title_entry.pack(fill='x', padx=10)

    # Messages input area
    tk.Label(root, text="Messages (Enter one per line, optional color separated by a comma):", font=("Arial", 12)).pack(pady=5)
    message_text = tk.Text(root, height=10, font=("Arial", 12))
    message_text.pack(fill='both', padx=10, pady=5)

    # Save button
    def save_config():
        title = title_entry.get()
        messages_with_colors = []
        
        for line in message_text.get("1.0", tk.END).strip().split("\n"):
            parts = line.split(",")
            message = parts[0].strip()
            color = parts[1].strip() if len(parts) > 1 else "black"
            messages_with_colors.append(f"{message}|{color}")
        
        config = configparser.ConfigParser()
        config['Dialog'] = {
            'Title': title if title else "My Dialog",
            'Messages': ";".join(messages_with_colors)
        }

        ini_file_path = filedialog.asksaveasfilename(defaultextension=".ini", filetypes=[("INI files", "*.ini")])
        if ini_file_path:
            with open(ini_file_path, 'w') as configfile:
                config.write(configfile)
            messagebox.showinfo("Saved", f"Configuration saved to {ini_file_path}")

    save_button = tk.Button(root, text="Save Configuration", command=save_config, font=("Arial", 14))
    save_button.pack(pady=20)

    root.mainloop()

configure_dialog()