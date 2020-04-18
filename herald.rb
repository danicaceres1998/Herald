# Gems
require 'csv'
require 'mail'

# Modules
module Logger
  @DIR_HIS_LOG = 'logs/history.log'
  @file = nil

  # Open the file
  def self.open_file
    @file = File.open(@DIR_HIS_LOG, 'a')
  end

  def self.close_file
    @file.close
  end

  # Function that log the actions
  def self.log(message)
    self.open_file
    @file.puts "#{message}"
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
      # Returns -> table[0]: id_br | table[1]: name_br | table[]2: id_prd | table[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';')
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    billers = []
    # row[1] -> name_brand
    billers = table.select {|row| row[1].downcase.include? biller_name}
  end

  # Function that returns ids of the selected products
  def get_biller(id_biller)
    begin
      # Returns -> table[0]: id_br | table[1]: name_br | table[]2: id_prd | table[3]: name_prd
      table = CSV.parse(File.read(@@DIR_DB), headers: true, col_sep: ';')
    rescue CSV::MalformedCSVError
      quote_chars.empty? ? raise : retry
    end
    biller = table.select {|row| row[0] == id_biller}
    puts biller
    biller
  end
  
  def main
    #Logger.log('============================================================')
    60.times {print '='}
    puts "\nLista de Correos:"
    30.times {print '-'}; puts
    @@EMAILS.length.times {|num| puts "*-) #{@@EMAILS[num]} ->\t#{num+1}"}
    print "\nIngrese el numero de su email: "
    @user_email = @@EMAILS[gets.chomp.to_i-1]
    puts "\nEmail to use -> #{@user_email}"
    # Searching the biller ID
    loop do
      puts "\nBuscar Facturador:"
      30.times {print '-'}; puts
      print "\nIngrese el nombre del facturador: "
      response = gets.chomp
      @id_brand = response
      break unless response.to_i == 0
      list_billers = self.search_billers(response)
      # row[0]: ID | row[1]: name_brand
      list_billers.each {|row| puts "*-) ID: #{row[0]}\tName: #{row[1]}"}
      print "\nOBS: Si desea salir ingrese el ID del facturador"
    end
    # Getting the biller
    @biller = self.get_biller(@id_brand)
    if @biller.empty?
      puts "No se encontro el Facturador, vuelva a intentar"; exit
    end
    # Disabling the service
    self.disable_service(@biller[0]['id_prd'], @biller[0]['name_brand'], @biller[0]['name_prd'])
    # Sending te email to the biller
    print "Ingrese los emails de los facturadores (separado por ';'): "
    @biller_contacts = gets.chomp
    @email_sender.send_email_biller(@user_email, biller[0]['name_brand'], @biller_contacts.split('; '))
    # Sending the email to the entities
    @email_sender.send_email_entities(@user_email, @biller[0]['name_brand'])
  end

end

class EmailSender
  # Class Constants
  @@DIR_EMAIL_ENTITIES = './emails/entities_email.txt'
  @@DIR_EMAIL_BILLER = './emails/biller_email.txt'

  def initialize
    @entities_contacts = nil
  end

  def read_email_entities(path_email)

  end

  def read_email_biller(path_email)

  end

  def send_email_entities(user_email, biller_name)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    message = self.read_email_entities(@@DIR_EMAIL_ENTITIES)
    # Configuration for send the email
    mail = Mail.new do
      from     user_email
      subject  "Avisos API Entidades - #{biller_name}"
      body     message
    end
    # Hidden Copy
    mail.bcc = @entities_contacts
  end

  def send_email_biller(user_email, biller_name, contacts)
    #  Configuration for the email
    Mail.defaults do
      delivery_method :smtp, address: '192.100.1.12', port: 25
    end
    # Reading and configurating the message
    message = self.read_email_biller(@@DIR_EMAIL_BILLER)
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
    rescue
      Logger.log('mensaje')
    end
  end

end

### MAIN ###
herald = Herald.new
herald.main