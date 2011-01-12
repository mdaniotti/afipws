module Afipws
  class WSAA
    def initialize
      @client = Savon::Client.new do
        # TODO parametrizar segun env
        wsdl.document = "https://wsaahomo.afip.gov.ar/ws/services/LoginCms?wsdl"
      end
    end
    
    # TODO ver si se puede poner un ttl mas largo
    def generar_tra service, ttl
      xml = Builder::XmlMarkup.new indent: 2
      xml.instruct!
      xml.loginTicketRequest version: 1 do
        xml.header do
          xml.uniqueId Time.now.to_i
          xml.generationTime xsd_datetime Time.now
          xml.expirationTime xsd_datetime Time.now + ttl
        end
        xml.service service
      end
    end
    
    def firmar_tra tra, key, crt
      key = OpenSSL::PKey::RSA.new key
      crt = OpenSSL::X509::Certificate.new crt
      OpenSSL::PKCS7::sign crt, key, tra
    end
    
    def codificar_tra pkcs7
      pkcs7.to_pem.lines.to_a[1..-2].join
    end
    
    def tra key, cert, service, ttl
      codificar_tra firmar_tra(generar_tra(service, ttl), key, cert)
    end
    
    def login key, cert, service = 'wsfe', ttl = 2400
      response = request :login_cms, :in0 => tra(key, cert, service, ttl)
      ta = Nokogiri::XML(Nokogiri::XML(response.to_xml).xpath('//loginCmsResponse').text)
      [ta.css('token').text, ta.css('sign').text]
    end
    
    def request action, body
      @client.request(action) { soap.body = body }
    end
    
    private
    def xsd_datetime time
      time.strftime('%Y-%m-%dT%H:%M:%S%z').sub /(\d{2})(\d{2})$/, '\1:\2'
    end
  end
end
