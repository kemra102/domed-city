module Dome
  class HieraLookups
    def initialize(environment)
      @environment  = environment.environment
      @account      = environment.account
      @settings     = Dome::Settings.new
    end

    def config
      config = YAML.load_file(File.join(puppet_dir, 'hiera.yaml'))
      config[:logger] = 'noop'
      config[:yaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:datadir] = "#{puppet_dir}/hieradata"
      config[:eyaml][:pkcs7_private_key] = eyaml_private_key
      config[:eyaml][:pkcs7_public_key] = eyaml_public_key
      config
    end

    def puppet_dir
      File.join(@settings.project_root, 'puppet')
    end

    def eyaml_private_key
      private_key = File.join(puppet_dir, 'keys/private_key.pkcs7.pem')
      raise "Cannot find eyaml private key! make sure it exists at #{private_key}" unless File.exist?(private_key)
      private_key
    end

    def eyaml_public_key
      public_key = File.join(puppet_dir, 'keys/public_key.pkcs7.pem')
      raise "Cannot find eyaml public key! make sure it exists at #{public_key}" unless File.exist?(public_key)
      public_key
    end

    def lookup(key, default = nil, order_override = nil, resolution_type = :priority)
      hiera = Hiera.new(config: config)

      hiera_scope = {}
      hiera_scope['ecosystem']  = @account
      hiera_scope['location']   = 'awseuwest1'
      hiera_scope['env']        = @environment

      hiera.lookup(key.to_s, default, hiera_scope, order_override, resolution_type)
    end

    def secret_env_vars(secret_vars = {})
      secret_vars.each_pair do |key, val|
        puts "setting TF_VAR: #{key}"
        ENV["TF_VAR_#{key}"] = lookup(val)
      end
    end

    def extract_certs(certs = {})
      cert_dir = "#{@settings.project_root}/terraform/certs"
      FileUtils.mkdir_p cert_dir

      certs.each_pair do |key, val|
        puts "Extracting cert #{key} into: #{cert_dir}/#{key}"
        File.open("#{cert_dir}/#{key}", 'w') { |f| f.write(lookup(val)) }
      end
    end
  end
end