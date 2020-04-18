# Gems
require 'csv'
require 'mail'
require "readline"

# Modules
module Logger
  @DIR_HIS_LOG = './logs/history.log'
  @MAX_BITS = 3145728
  @file = nil

  # Open the file
  def self.open_file
    @file = File.open(@DIR_HIS_LOG, 'a')
  end

  # Close the file
  def self.close_file
    @file.close
  end

  # Function that log the actions
  def self.log(message)
    self.open_file
    @file.puts "#{message}"
    self.close_file
  end

  # First log
  def self.init_log(message)
    self.open_file
    if @file.size > @MAX_BITS
      File.delete(@DIR_HIS_LOG)
      system("touch #{@DIR_HIS_LOG}")
    end
    @file.puts "=================================================="
    @file.puts "Begin: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    @file.puts "#{message}"
    self.close_file
  end

  def self.last_log
    self.open_file
    @file.puts "End: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    self.close_file
  end

end

# Classes
class Herald
  # Class Constants
  @@CANT_BITS = 3145728
  @@DIR_DB = './data/data.csv'
  @@EMAILS = %w[
    natasha.correa@bancard.com.py
    carlos.villalba@bancard.com.py
    juan.ojeda@bancard.com.py
    jose.cantero@bancard.com.py
  ]

  def initialize
    @email_sender = EmailSender.new()
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
    #system(petition)
  end

  # Function that returns names of the billers
  def search_billers(biller_name)
    begin
      # Returns -> row[0]: id_br | row[1]: name_br | row[2]: id_prd | row[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';')
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    # row[1] -> name_brand
    billers = table.select {|row| row[1].downcase.include? biller_name}
  end

  # Function that returns ids of the selected products
  def get_biller(id_biller)
    begin
      # Returns -> table[0]: id_br | table[1]: name_br | table[2]: id_prd | table[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';')
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    biller = table.select {|row| row[0] == id_biller}
  end
  
  # Main Function
  def main
    60.times {print '='}
    puts "\nLista de Correos:"
    30.times {print '-'}; puts
    @@EMAILS.length.times {|num| puts "*-) #{@@EMAILS[num]} ->\t#{num+1}"}
    print "\nIngrese el numero de su email: "
    @user_email = @@EMAILS[gets.chomp.to_i-1]
    puts "\nEmail a usar -> #{@user_email}"
    # Searching the biller ID
    loop do
      puts "\nBuscar Facturador:"
      30.times {print '-'}; puts
      print "\nIngrese el nombre del facturador: "
      @id_brand = gets.chomp
      break unless @id_brand.to_i == 0
      list_billers = self.search_billers(@id_brand)
      # row[0]: ID | row[1]: name_brand
      list_billers.each {|row| puts "*-) ID: #{row[0]}\tNombre: #{row[1]}"}
      print "\nOBS: Si desea salir ingrese el ID del facturador"
    end
    # Getting the biller
    @biller = self.get_biller(@id_brand)
    if @biller.empty?
      puts "No se encontro el Facturador, vuelva a intentar"; exit
    end
    # Showing the products
    puts "\nSe desabilitara los productos de: #{@biller[0]['name_brand']}"
    @biller.each {|row| puts "*-) ID: #{row[2]}\tNombre: #{row[3]}"}
    print "\nDesea continuar y/n: "
    exit unless gets.chomp.downcase == 'y'
    # Disabling the service
    @biller.each do |row|
      self.disable_service(row[2], row[1], row[3])
    end
    # Saving all the facts
    Logger.init_log("The user: #{@user_email}\nDisabled the products of: #{@biller[0]['name_brand']}")
    # Getting the biller emails
    30.times {print '-'}; puts
    print "\nIngrese los emails de los facturadores (separado por '; '): "
    @biller_contacts = gets.chomp
    # Getting the error to send
    error = []
    30.times {print '-'}; puts
    print "\nCopie y pegue aqui el error:"
    puts "\nOBS: Para salir ingrese -> q"
    while buf = Readline.readline("> ", true)
      break if buf == 'q'
      error.push(buf)
    end
    # Sending the emial to the biller
    @email_sender.send_email_biller(@user_email, @biller[0]['name_brand'], @biller_contacts.split('; '), error.join("\n"))
    # Sending the email to the entities
    products = []
    @biller.each {|row| products.push("ID: #{row[2]}\tNombre: #{row[3]}")}
    @email_sender.send_email_entities(@user_email, @biller[0]['name_brand'], products, error.join("\n"))
    # Finishing all
    Logger.last_log
  end

end

class EmailSender
  # Class Constants
  @@DIR_EMAIL_ENTITIES = './emails/entities_email.txt'
  @@DIR_EMAIL_BILLER = './emails/biller_email.txt'
  @@DIR_CCO_ENTITIES = './emails/entities_contacts.txt'

  def initialize
    @entities_contacts = []
  end

  def read_email_entities(biller_name, products, error)
    # Getting the message
    message = Time.now.strftime('%H').to_i < 12 ? 'Buenos dias' : 'Buenas Tardes'
    File.foreach(@@DIR_EMAIL_ENTITIES) do |line|
      message += line
    end
    # Changing the message
    message['BILLER'] = biller_name
    message['ERROR_LOG'] = error
    brand_product = ''
    products.each {|prd| brand_product += "#{biller_name} -> #{prd}\n"}
    message['BILLER_PRODUCTS'] = brand_product
    puts message
  end

  def read_email_biller(biller_name, error)
    # Getting the message
    message = Time.now.strftime('%H').to_i < 12 ? 'Buenos dias' : 'Buenas Tardes'
    File.foreach(@@DIR_EMAIL_BILLER) do |line|
      message += line
    end
    # Changing the message
    message['BILLER'] = biller_name
    message['ERROR_LOG'] = error
    puts message
  end

  def get_cco_contacts
    File.foreach(@@DIR_CCO_ENTITIES) do |line|
      @entities_contacts.push(line)
    end
    puts "#{@entities_contacts}"
  end

  def send_email_entities(user_email, biller_name, products, error)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    message = self.read_email_entities(biller_name, products, error)
    # Configuration for send the email
    mail = Mail.new do
      from     user_email
      subject  "Avisos API Entidades - #{biller_name}"
      body     message
    end
    # Hidden Copy
    self.get_cco_contacts
    mail.bcc = @entities_contacts
    # Sending the email
    begin
      mail.deliver!
      Logger.log("SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Entities emails sended to: #{contacts.join('; ')}")
    rescue
      Logger.log("ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Unable to send Entities emails to: #{contacts.join('; ')}")
    end
  end

  def send_email_biller(user_email, biller_name, contacts, error)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    message = self.read_email_biller(biller_name, error)
    # Configuration for send the email
    mail = Mail.new do
      from     user_email
      subject  "Avisos Facturadores - #{biller_name}"
      body     message
    end
    # Contacts of the Biller
    mail.to = contacts
    # Sending the email
    begin
      mail.deliver!
      Logger.log("SUCCESS #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Biller Emails sended to: #{contacts.join('; ')}")
    rescue
      Logger.log("ERROR #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} -> Unable to send Biller emails to: #{contacts.join('; ')}")
    end
  end

end

### MAIN ###
herald = Herald.new
herald.main