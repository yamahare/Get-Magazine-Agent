require 'open-uri' # URLにアクセスするためのライブラリの読み込み
require 'mysql2'
require 'yaml'

#このファイルがあるパスを起点にして同階層のconfig/dbconfig.ymlを参照する
config = YAML.load_file(File.expand_path('../config/dbconfig.yml', __FILE__))

name = config["db"]["host"]
user = config["db"]["user"]
pass = config["db"]["pass"]
db_name = config["db"]["db_name"]

client = Mysql2::Client.new(host: name \
                          , username: user \
                          , password: pass \
                          , database: db_name)

query = %{SELECT url
                ,file_path
          FROM   url_and_regex
        }
results = client.query(query)

path_array = Array.new(results.count).map{Array.new(2)}

results.each_with_index do |row, i| 
  path_array[i][0] = row["url"]
  path_array[i][1] = row["file_path"]
end

path_array.uniq! #重複を削除

path_array.each do |row|
  html = open(row[0]) do |f|
    f.read # htmlを読み込んで変数htmlに渡す
  end

  #ディレクトリが存在しない場合作成する
  if !(Dir.exist?(File.expand_path('../', __FILE__) + File.dirname(row[1]))) then
    FileUtils.mkdir(File.expand_path('../', __FILE__) + File.dirname(row[1]))  
  end

  File.open(File.expand_path('../', __FILE__) + row[1], 'w') do |file|
    file.puts(html)
  end
end
