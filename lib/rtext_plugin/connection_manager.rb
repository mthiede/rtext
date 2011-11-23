module RTextPlugin

class ConnectorManager
  def start
  end
  
  def stop
  end
  
  def trigger
  end
   
private

  def find_rtext_config_file(file)
  end

  def extract_file_pattern(file)
    ext = File.extname
    if ext.size > 0
      "*.#{ext}"
    else
      File.basename(file)
    end
  end

  ServiceSpec = Struct.new(:config_file, :pattern, :command)
   
  def parse_rtext_config_file(file)
    expect = :pattern
    line = 1
    pattern = nil
    specs = []
    File.open(file) do |f|
      f.readlines.each do |l|
        case expect
        when :pattern
          if l =~ /(.*):\s*$/
            pattern = $1.split(",").collect{|s| s.strip} 
            expect = :command
          else
            raise "expected file pattern in line #{line}"
          end
        when :command
          if l =~ /[^:]\s*$/
            specs << ServiceSpec.new(file, pattern, l)
          else
            raise "expected command in line #{line}"
          end
        end
        line += 1
      end
    end
    specs
  end

end

end
