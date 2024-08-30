import tkinter as tk
from tkinter import messagebox
import configparser
import os, sys

############################
#usage to get exe file with specific logo (logo.ico):
# pyinstaller --onefile --windowed --noconsole --icon=logo.ico MessageBox.py
ini_file_name = 'MessageBox.ini'
icon_name = 'MessageBoxIcon.ini'
############################

#for icon (when we want to use icon as an argument)

#def resource_path(relative_path):
#    try:
#        base_path = sys._MEIPASS
#    except Exception:
#        base_path = os.path.abspath(".")

#    return os.path.join(base_path, relative_path)


def get_window_settings_from_config(config):
    """ Get the window dimensions, font, and text justification from the config file. """
    try:
        width = int(config.get('Window', 'Width', fallback='640'))
        if width == 0:
            width = 640
    except ValueError:
        width = 640

    try:
        height = int(config.get('Window', 'Height', fallback='480'))
        if height == 0:
            height = 480
    except ValueError:
        height = 480

    font_name = config.get('Window', 'FontName', fallback='Arial')
    try:
        font_size = int(config.get('Window', 'FontSize', fallback='24'))
    except ValueError:
        font_size = 24

    justify = config.get('Window', 'Justify', fallback='center').lower()
    if justify not in ['left', 'center', 'right']:
        justify = 'center'  # Default to 'center' if invalid

    return width, height, font_name, font_size, justify

def get_colors_from_config(config):
    """ Get window and button background colors from the config file. """
    window_bg = config.get('Window', 'WindowBackground', fallback='white')
    button_bg = config.get('Window', 'ButtonBackground', fallback='lightgrey')
    return window_bg, button_bg

def show_dialogue_from_ini(ini_file):
    # Check if the ini file exists
    if not os.path.exists(ini_file):
        messagebox.showerror("Error", f"The file '{ini_file}' does not exist.")
        return
    
    # Parse the ini file with UTF-8 encoding
    config = configparser.ConfigParser(allow_no_value=True)
    try:
        with open(ini_file, 'r', encoding='utf-8') as file:
            config.read_file(file)
    except Exception as e:
        messagebox.showerror("Error", f"Error reading INI file: {e}")
        return

    # Get the title from the [Title] section
    title = config.get('Title', 'Title', fallback='Title')

    # Get messages from the [Messages] section
    messages = []
    if 'Messages' in config:
        for key in config['Messages']:
            if key.startswith('message'):
                message = config.get('Messages', key).replace('\\n', '\n')  # Handle multi-line messages
                messages.append(message)
    else:
        messagebox.showerror("Error", "The 'Messages' section is missing from the INI file.")
        return
    
    # Get colors from the [MessageColors] section
    colors = []
    if 'MessageColors' in config:
        for i in range(1, len(messages) + 1):
            color_key = f'MessageColor{i}'
            color = config.get('MessageColors', color_key, fallback='black')
            colors.append(color)
    else:
        colors = ['black'] * len(messages)  # Default colors if 'MessageColors' section is missing

    # Get window settings from the [Window] section
    width, height, font_name, font_size, justify = get_window_settings_from_config(config)

    # Get background colors from the [MessageColors] section
    window_bg, button_bg = get_colors_from_config(config)

    # Create the main window
    dialog = tk.Tk()
    dialog.title(title)
    dialog.resizable(False, False)
    dialog.iconbitmap(("MessageBoxIcon.ico"))
    
    # Set the window size and background color
    dialog.geometry(f"{width}x{height}")
    dialog.configure(bg=window_bg)
    
    # Display the messages
    for message, color in zip(messages, colors):
        label = tk.Label(dialog, text=message, font=(font_name, font_size), wraplength=width - 40, fg=color, justify=justify, bg=window_bg)
        label.pack(pady=10, padx=20, anchor=tk.N)

    # Create an OK button to close the dialog
    ok_button = tk.Button(dialog, text="OK", command=dialog.destroy, width=12, height=2, font=("Arial", 14), bg=button_bg, fg='black')
    ok_button.pack(pady=10, side='bottom')

    # Center the window on the screen
    dialog.update_idletasks()
    dialog.geometry(f'{width}x{height}+{(dialog.winfo_screenwidth() - width) // 2}+{(dialog.winfo_screenheight() - height) // 2}')

    # Start the Tkinter event loop
    dialog.mainloop()

# Automatically show the dialog when the program starts
ini_file_path = ini_file_name  # Ensure this file is in the same directory as the exe
show_dialogue_from_ini(ini_file_path)