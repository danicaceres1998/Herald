#!/usr/bin/env ruby
# Gems
require 'csv'
require 'mail'
require 'readline'

# Modules
module MyLogger
  @@DIR_DOWNB_LOG = '/home/sodepusr/Herald/logs/down_billers.log'
  @@DIR_TRACKB_LOG = '/home/sodepusr/Herald/logs/tracking_billers.log'
  @MAX_BYTES = 3145728
  @file = nil

  # Open the file
  def self.open_file(path)
    @file = File.open(path, 'a')
  end

  # Close the file
  def self.close_file
    @file.close
  end

  # Function that log the actions
  def self.log(message, is_active_email)
    is_active_email ? path = @@DIR_TRACKB_LOG : path = @@DIR_DOWNB_LOG
    self.open_file(path)
    @file.puts "#{message}"
    self.close_file
  end

  # First log
  def self.init_log(message, is_active_email)
    is_active_email ? path = @@DIR_TRACKB_LOG : path = @@DIR_DOWNB_LOG
    self.open_file(path)
    if @file.size > @MAX_BYTES
      File.delete(@DIR_HIS_LOG)
      system("touch #{@DIR_HIS_LOG}")
    end
    @file.puts "=================================================="
    @file.puts "Begin: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    @file.puts "#{message}"
    self.close_file
  end

  # Last log
  def self.last_log(is_active_email)
    is_active_email ? path = @@DIR_TRACKB_LOG : path = @@DIR_DOWNB_LOG
    self.open_file(path)
    @file.puts "End: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    self.close_file
  end

end

# Classes
class Herald
  # Class Constants
  @@DIR_DB = '/home/sodepusr/Herald/data/data.csv'
  @@DEFAULT_EMAIL = ''
  @@EMAILS = %w[
    natasha.correa@bancard.com.py
    carlos.villalba@bancard.com.py
    juan.ojeda@bancard.com.py
    jose.cantero@bancard.com.py
  ]

  def initialize
    @email_sender = EmailSender.new
    @serializer = Serializer.new
    @user_email = ''
    @biller_contacts = ''
    @id_brand = nil
    @biller = nil
  end

  # Function that disable one service
  def disable_service(id_product, biller_name, product_name)
    puts "\nDisabling service ..."
    petition = "curl -X POST -u 'apps/i9Pc7v5W8m4jVaPc51a14RiA5K8TLGmy:59fRSmdYHljB.Yew6wCGdRTADF6eSCwc05gXnCfs' "
    petition += "https://10.10.17.104:4481/billing/api/0.2/extra_product_params -F 'extra_product_params[product_id]=#{id_product}' -F "
    petition += "'extra_product_params[group]=notification_message' -F 'extra_product_params[params][message]="
    petition += "El servicio #{biller_name} - #{product_name} se encuentra en mantenimiento, lo estaremos restableciendo en la brevedad posible' -k"
    puts petition
    system(petition)
  end

  # Function that returns names of the billers
  def search_billers(biller_name)
    quote_chars = %w[" | ~ ^ & *]
    begin
      # Returns -> row[0]: id_br | row[1]: name_br | row[2]: id_prd | row[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';', quote_char: quote_chars.shift)
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    # row[1] -> name_brand
    billers = table.select {|row| row[1].downcase.include? biller_name}
  end

  def biller_search
    loop do
      puts "\nBuscar Facturador:"
      30.times {print '-'}; puts
      print "\nIngrese el nombre del facturador o su ID: "
      @id_brand = gets.chomp
      break unless @id_brand.to_i == 0
      list_billers = self.search_billers(@id_brand)
      puts "\nResultado de la busqueda:"
      30.times {print '-'}; puts
      # row[0]: ID | row[1]: name_brand
      list_billers.each {|row| puts "*-) ID: #{row[0]}\tNombre: #{row[1]}"}
      puts "\nOBS: Si desea elegir el facturador ingrese el ID del mismo!"
    end
  end

  # Function that returns ids of the selected products
  def get_biller(id_biller)
    quote_chars = %w[" | ~ ^ & *]
    begin
      # Returns -> table[0]: id_br | table[1]: name_br | table[2]: id_prd | table[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';', quote_char: quote_chars.shift)
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    biller = table.select {|row| row[0] == id_biller}
  end

  # Main Function
  def main
    system('clear')
    60.times {print '='}; puts
    puts "\t\t\t  HERALD"
    60.times {print '='}; puts
    puts "\nDar de Baja un Facturador ->\t1"
    puts "Dar de Alta un Facturador ->\t2"
    print "Elija la opcion que desee (ingrese el numero): "
    response = gets.chomp.to_i
    case response
    when 1
      self.disable_biller
    when 2
      self.active_biller
    else
      puts "ERROR: Opcion invalida"; exit
    end
  end

  # Function for active a biller
  def active_biller
    system('clear')
    60.times {print '='}
    puts "\nLista de Correos:"
    30.times {print '-'}; puts
    @@EMAILS.length.times {|num| puts "*-) #{@@EMAILS[num]} ->\t#{num+1}"}
    print "\nIngrese el numero de su email: "
    @user_email = @@EMAILS[gets.chomp.to_i-1]
    puts "\nEmail a usar -> #{@user_email}"
    # Searching the biller ID
  end
  
  # Function for disable a biller
  def disable_biller
    system('clear')
    60.times {print '='}
    puts "\nLista de Correos:"
    30.times {print '-'}; puts
    @@EMAILS.length.times {|num| puts "*-) #{@@EMAILS[num]} ->\t#{num+1}"}
    print "\nIngrese el numero de su email: "
    @user_email = @@EMAILS[gets.chomp.to_i-1]
    puts "\nEmail a usar -> #{@user_email}"
    # Searching the biller ID
    self.biller_search
    # Getting the biller
    @biller = self.get_biller(@id_brand)
    loop do
      break unless @biller.empty?
      puts "ERROR: No se encontro el Facturador, vuelva a intentar!"
      self.biller_search
      @biller = self.get_biller(@id_brand)
    end
    # Showing the products
    puts "\nSe desabilitaran los productos de: #{@biller[0]['name_brand']}"
    60.times {print '-'}; puts
    @biller.each {|row| puts "*-) ID: #{row[2]}\tNombre: #{row[3]}"}
    print "\nDesea continuar y/n: "
    exit unless gets.chomp.downcase == 'y'
    # Disabling the service
    @biller.each {|row| self.disable_service(row[2], row[1], row[3])}
    # Saving all the actions
    MyLogger.init_log("The user: #{@user_email}\nDisabled the products of: #{@biller[0]['name_brand']}", false)
    # Getting the biller emails
    60.times {print '-'}; puts
    print "\nIngrese los emails de los contactos de los facturadores (separados por '; '): "
    @biller_contacts = gets.chomp
    # Getting the error to send
    error = []
    loop do
      60.times {print '-'}; puts
      print "\nCopie y pegue aqui el error:"
      puts "\nOBS: Para continuar ingrese -> Q/q"
      while buf = Readline.readline("> ", true)
        break if buf == 'q' or buf == 'Q'
        error.push(buf)
      end
      error.empty? ? puts("ERROR: No ingreso el error a reportar, favor ingresarlo !\n") : break
    end
    # Sending the emial to the biller
    @email_sender.send_email_biller(@user_email, @biller[0]['name_brand'], @biller_contacts.split('; '), error.join("\n"), false)
    # Sending the email to the entities
    products = []
    @biller.each {|row| products.push("ID: #{row[2]}\tNombre: #{row[3]}")}
    @email_sender.send_email_entities(@user_email, @biller[0]['name_brand'], products, error.join("\n"), false)
    # Finishing all
    MyLogger.last_log(false)
    @serializer.add_biller(@id_brand, @biller[0]['name_brand'], @biller_contacts)
    puts "\nINFO: Procesos Finalizados Correctamente!"; puts
  end

end

# Object Serializer
class Serializer
  # Class Constants
  @@DATA_FILE = '/home/sodepusr/Herald/data/billers'

  def initialize
    if File.size(@@DATA_FILE) == 0
      File.open(@@DATA_FILE, 'w+') do |file|  
        Marshal.dump([], file)  
      end
    end
    @list_billers = nil
  end

  def get_tracking_billers
    # Getting the list of billers
    File.open(@@DATA_FILE) do |f|  
      @list_billers = Marshal.load(f)  
    end
    # Returning the list
    @list_billers
  end

  def add_biller(id_brand, brand_name, biller_contacts)
    # Getting the list of billers
    File.open(@@DATA_FILE) do |f|  
      @list_billers = Marshal.load(f)  
    end
    # Saving the new biller to track
    Struct.new("BillerStruct", :id_brand, :brand_name, :biller_contacts)
    biller = Struct::BillerStruct.new(id_brand, brand_name, biller_contacts)
    @list_billers.push(biller)
    # Serializing the biller
    File.open(@@DATA_FILE, 'w+') do |file|  
      Marshal.dump(@list_billers, file)  
    end
  end

  def delete_biller(id_brand)
    # Getting the list of billers
    File.open(@@DATA_FILE) do |f|  
      @list_billers = Marshal.load(f)  
    end
    # Searching the biller
    deleted_biller = nil
    @list_billers.each do |biller| 
      if biller.id_brand == id_brand
        deleted_biller = @list_billers.delete_at(@list_billers.index(biller))
        break
      end
    end
    # Saving the new list of billers
    File.open(@@DATA_FILE, 'w+') do |file|  
      Marshal.dump(@list_billers, file)  
    end
    # Returning the deleted biller
    deleted_biller
  end

end

class EmailSender
  # Class Constants
  @@DIR_EMAIL_ENTITIES = '/home/sodepusr/Herald/emails/entities_email.txt'
  @@DIR_EMAIL_BILLER = '/home/sodepusr/Herald/emails/biller_email.txt'
  @@DIR_CCO_ENTITIES = '/home/sodepusr/Herald/emails/entities_contacts.txt'
  @@DIR_CC_CONTACTCS = '/home/sodepusr/Herald/emails/cc_contacts.txt'
  @@DIR_ACTIVE_EMAIL = '/home/sodepusr/Herald/emails/active_biller_email.txt'

  def initialize
    @entities_contacts = []
    @cc_contacts = []
  end

  def read_email_entities(biller_name, products, error, path, is_active_email)
    # Getting the message
    message = Time.now.strftime('%H').to_i < 12 ? 'Buenos Dias' : 'Buenas Tardes'
    File.foreach(path, "r:UTF-8")  {|line| message += line}
    # Changing the message
    if is_active_email
      message['BILLER'] = biller_name
    else
      message['BILLER'] = biller_name
      message['ERROR_LOG'] = error
      brand_product = ''
      products.each {|prd| brand_product += "-> #{prd}\n"}
      message['BILLER_PRODUCTS'] = brand_product
    end
    # Returning the message
    message
  end

  def read_email_biller(biller_name, error, path, is_active_email)
    # Getting the message
    message = Time.now.strftime('%H').to_i < 12 ? 'Buenos Dias' : 'Buenas Tardes'
    File.foreach(path, "r:UTF-8")  {|line| message += line}
    # Changing the message
    if is_active_email
      message['BILLER'] = biller_name
    else
      message['BILLER'] = biller_name
      message['ERROR_LOG'] = error
    end
    # Returning the message
    message
  end

  def get_contacts(path, contacts)
    File.foreach(path) do |line|
      contacts.push(line)
    end
  end

  def send_email_entities(user_email, biller_name, products, error, is_active_email)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    is_active_email ? path = @@DIR_ACTIVE_EMAIL : path = @@DIR_EMAIL_ENTITIES
    message = self.read_email_entities(biller_name, products, error, path, is_active_email)
    # Configuration for send the email
    mail = Mail.new do
      from     user_email
      subject  "Avisos API Entidades - #{biller_name}"
      body     message
    end
    mail.charset = 'UTF-8'
    mail.content_transfer_encoding = '8bit'
    # Hidden Copy
    self.get_contacts(@@DIR_CCO_ENTITIES, @entities_contacts)
    mail.bcc = @entities_contacts.join('; ')
    # Sending the email
    begin
      mail.deliver!
      puts "SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Entities email sended (see the contacts in Herald/emails/entities_contacts.txt)"
      MyLogger.log("SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Entities email sended (see the contacts in Herald/emails/entities_contacts.txt)", is_active_email)
    rescue Exception => msg
      puts "ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Unable to send Entities email (see the contacts in Herald/emails/entities_contacts.txt)"
      MyLogger.log("ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}: #{msg} -> Unable to send Entities email (see the contacts in Herald/emails/entities_contacts.txt)", is_active_email)
    end
  end

  def send_email_biller(user_email, biller_name, contacts, error, is_active_email)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    is_active_email ? path = @@DIR_ACTIVE_EMAIL : path = @@DIR_EMAIL_BILLER
    message = self.read_email_biller(biller_name, error, path, is_active_email)
    # Configuration for send the email
    mail = Mail.new do
      from     user_email
      subject  "Avisos Facturadores - #{biller_name}"
      body     message
    end
    mail.charset = 'UTF-8'
    mail.content_transfer_encoding = '8bit'
    # Contacts of the Biller
    mail.to = contacts.join('; ')
    self.get_contacts(@@DIR_CC_CONTACTCS, @cc_contacts)
    mail.cc = @cc_contacts.join('; ')
    # Sending the email
    begin
      mail.deliver!
      puts "SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Biller email sended to: #{contacts.join('; ')}"
      MyLogger.log("SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Biller email sended to: #{contacts.join('; ')}", is_active_email)
    rescue Exception => msg
      puts "ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Unable to send Biller email to: #{contacts.join('; ')}"
      MyLogger.log("ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}: #{msg} -> Unable to send Biller email to: #{contacts.join('; ')}", is_active_email)
    end
  end

end

### MAIN ###
herald = Herald.new
herald.main