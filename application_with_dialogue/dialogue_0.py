import tkinter as tk
import configparser

def show_custom_dialog(ini_file_path):
    # Read the configuration
    config = configparser.ConfigParser()
    config.read(ini_file_path)
    
    title = config['Dialog']['Title']
    messages_with_colors = [
        (msg.split("|")[0], msg.split("|")[1])
        for msg in config['Dialog']['Messages'].split(";")
    ]
    
    # Create the dialog window
    dialog = tk.Tk()
    dialog.title(title)
    l = 30 + len(messages_with_colors) * 90
    dialog.geometry(f"640x{l}") 

    for message, color in messages_with_colors:
        label = tk.Label(dialog, text=message, font=("Times New Roman", 24), fg=color, wraplength=600)
        label.pack(pady=10, padx=20)

    ok_button = tk.Button(dialog, text="OK", command=dialog.destroy, width=10, height=2, font=("Times New Roman", 14))
    ok_button.pack(pady=10)

    dialog.update_idletasks()

    # Center the dialog on the screen
    width = 640  # Fixed width
    height = dialog.winfo_height()  # Adjust to content
    x = (dialog.winfo_screenwidth() // 2) - (width // 2)
    y = (dialog.winfo_screenheight() // 2) - (height // 2)
    dialog.geometry(f'{width}x{height}+{x}+{y}')

    dialog.mainloop()

# Specify the path to the .ini file
ini_file_path = 'initt.ini'
show_custom_dialog(ini_file_path)