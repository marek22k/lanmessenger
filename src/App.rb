
require_relative "MainWindow.rb"
require_relative "InitWindow.rb"
require "fox16"

app = Fox::FXApp.new appName: "Banduras Lan Messenger", vendorName: "Bandura"
init = InitWindow.new app
main = MainWindow.new app
init.connect_main_window main
app.create
app.run
