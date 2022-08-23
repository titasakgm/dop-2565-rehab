#!/usr/local/bin/ruby

require 'sinatra'
require 'roo'
require 'pg'
require 'faraday'

require 'pry-byebug'

set :bind, '0.0.0.0'

def log(sql)
  fp = open("public/sql.log","a")
  fp.write("#{sql}\n")
  fp.close
end

def get_bbox
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "SELECT st_extent(geom) as bbox "
  sql += "FROM provinces "
  sql += "WHERE adm1_pcode='TH#{@pcode}' "
  res = con.exec(sql)
  con.close
  bbox = res[0]['bbox'].gsub('BOX(','[').tr(' ',',').tr(')',']')
  eval(bbox)
end

def get_loc(tcode)
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "SELECT acode as ccaa,amp,cwt,latitude as lat,longitude as lon "
  sql += "FROM v_dop_info "
  sql += "WHERE tcode='#{tcode}' "
  puts sql
  begin
    res = con.exec(sql)
  rescue
    log(sql)
    exit
  end
  con.close
  if res.num_tuples == 0
    result = [tcode[2..5],'NA','NA',0.0,0.0]
  else
    result = res[0].values
  end
  result
end

def get_cwt_amp(ccaa)
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "SELECT DISTINCT changwat,amphoe FROM ccaatt "
  sql += "WHERE cc='#{ccaa[0..1]}' and aa='#{ccaa[2..3]}' "
  res = con.exec(sql)
  con.close
  cwt = res[0]['changwat'].to_s.gsub('จังหวัด','')
  amp = res[0]['amphoe'].to_s.gsub('อำเภอ','')
  [cwt,amp]
end

def get_office(name)
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "SELECT * FROM dop_offices_65 "
  sql += "WHERE office_name LIKE '%#{name}%' "
  res = con.exec(sql)
  con.close
  res[0].values
end

def save_pg(arr)
  vals = arr.join("','")
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "INSERT INTO dop_data (ccaa,amphoe,changwat,lat,lon,type,count) "
  sql += "VALUES ('#{vals}') "
  sql += "ON CONFLICT (ccaa,type) "
  sql += "DO "
  sql += "UPDATE SET count=dop_data.count "
  res = con.exec(sql)
  con.close
end

def save_dop_dat
  #@type1 => {'TH<ccaa>',count } use location of tambon01
  @type1.each do |k,v|
    next if k == 'NA'
    tcode = k[2..5] + '01'
    info = get_loc(tcode) + ['1',v] # [ccaa,amp,cwt,lat,lon] + ['1',v]
    save_pg(info)
  end
  #@type2 => {'TH<ccaa>',count } use location of tambon03
  @type2.each do |k,v|
    next if k == 'NA'
    tcode = k[2..5] + '02'
    info = get_loc(tcode) + ['2',v] # [ccaa,amp,cwt,lat,lon] + ['2',v]
    save_pg(info)
  end
  #@type3 => {'TH<ccaa>',count } use location of tambon05
  @type3.each do |k,v|
    next if k == 'NA'
    tcode = k[2..5] + '03'
    info = get_loc(tcode) + ['3',v] # [ccaa,amp,cwt,lat,lon] + ['2',v]
    save_pg(info)
  end
end

def get_lat_lon(ccaatt)
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "SELECT "
  con.close
end

def save_data(arr)
  vals = arr.join("','")
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  sql = "INSERT INTO dop_data VALUES ('#{vals}') "
  begin
    res = con.exec(sql)
  rescue
    log(sql)
  end
  con.close
end

def check_amp_cwt(amp,cwt)
  con = PG::Connection.connect("172.17.0.1",5432,nil,nil,"pgis","postgres","dop@2022")
  if amp.to_s.length > 0
    sql = "select adm2_pcode as ccaa,adm1_th as changwat "
    sql += ",adm2_th as amphoe "
    sql += "FROM amphoes "
    sql += "WHERE adm1_th % '#{cwt}' "
    sql += "AND adm2_th % '#{amp}' "
  else
    sql = "SELECT adm1_pcode || '00' as ccaa,adm1_th as changwat "
    sql += "'NA' as amphoe "
    sql += "FROM amphoes "
    sql += "WHERE adm1_th % '#{cwt}' "
  end
  # puts sql
  res = con.exec(sql)
  con.close
  if res.num_tuples == 0
    info = ['NA','NA','NA']
  else
    info = res[0].values
  end
  if info.join('') !~ /นคร/
    puts sql
    puts info.join('|')
  end
  info
end

def list_files
  @files = []
  @sizes = []
  # list files in public/uploads
  entries = Dir.entries("./public/uploads") - ['.','..']
  @files = []
  # binding.pry
  entries.sort.each do |file|
    size = File.size("./public/uploads/#{file}")
    @files.push(file)
    @sizes.push(size)
  end
end

get '/' do
  redirect '/upload'
end

get '/map' do
  @pcode = params[:pcode]
  @bbox = get_bbox
  text "Under construction!"
  #erb :view_map
end

get '/office/:name' do
  @off_info = get_office(params[:name])

  erb :off_info
end

get '/upload' do
    @files = list_files
    erb :upload
end

post '/upload' do
  if params[:file]
    filename = params[:file][:filename]
    tempfile = params[:file][:tempfile]
    target = "public/uploads/#{filename}"

    File.open(target, 'wb') {|f| f.write tempfile.read }
  end
  redirect '/upload'
end

get '/delete/:file' do
  if params[:file]
    filename = params[:file]
    File.delete("/opt/SINATRA/public/uploads/#{filename}")
  end
  redirect '/upload'
end

get '/report' do
  if params[:file]
    # new filename: 8002-65-01-<province>-<branch>-65-?????
    xls_name = params[:file]
    f = xls_name.split('-')
    ccaa = f[0]
    changwat,amphoe = get_cwt_amp(ccaa)
    fyear = "25#{f[1]}"
    batch = f[2].to_i
    branch = (f[1] == f[4]) ? nil : f[4]
    # get office_id, office_name from changwat or branch
    if branch.nil?
      @off_info = get_office(changwat)
    else
      @off_info = get_office(branch)
    end
    # add batch to @off_info    
    @off_info.push(batch)

    # process .xlsx
    fn = "public/uploads/#{params[:file]}"
    xlsx = Roo::Spreadsheet.open(fn)
    # Sheets: addict, dealer, officer
    # LINE1 = header: ลำดับ อำเภอ จังหวัด
    @info1 = {} # addict changwat for type 1
    @info2 = {} # addict amphoe for type 1
    @info3 = {} # dealer changwat for type 2
    @info4 = {} # dealer amphoe for type 2
    @info5 = {} # office changwat for type 3
    @info6 = {} # office amphoe for type 3
    @type1 = {}
    @type2 = {}
    @type3 = {}
    @pcode = nil

    # addict
    add = xlsx.sheet('addict')
    # puts "last_row: #{add.last_row}"
    (2..add.last_row).each do |row|
      d = add.row(row)
      ord = d[0].to_i
      amp = d[1] || 'NA' # case amp is nil
      cwt = d[2] || 'NA' # case cwt is nil

      # FIX amp == เมือง
      if amp == "เมือง"
        amp += cwt
      end
      if !@info1.key?(cwt) # count changwat
        @info1[cwt] = 1
      else
        @info1[cwt] += 1
      end
      # count amp in each province
      if @info2.keys.include?(cwt)
        if @info2[cwt].keys.include?(amp)
           @info2[cwt][amp] += 1
        else
           @info2[cwt][amp] = 1 # set count amp in cwt = 1
        end
      else
        @info2[cwt] = {}
        @info2[cwt][amp] = 1
      end
    end

    # dealer
    dlr = xlsx.sheet('dealer')
    # puts "last_row: #{dlr.last_row}"
    (2..dlr.last_row).each do |row|
      d = dlr.row(row)
      ord = d[0].to_i
      amp = d[1] || 'NA' # case amp is nil
      cwt = d[2] || 'NA' # case cwt is nil

      # recode amp == เมือง
      if amp == 'เมือง'
        amp += cwt
      end
      if !@info3.key?(cwt) # count changwat
        @info3[cwt] = 1
      else
        @info3[cwt] += 1
      end
      # count amp in each province
      if @info4.keys.include?(cwt)
        if @info4[cwt].keys.include?(amp)
          @info4[cwt][amp] += 1
        else
          @info4[cwt][amp] = 1 # set count amp in cwt = 1
        end
      else
        @info4[cwt] = {}
        @info4[cwt][amp] = 1
      end
    end

    # officer
    off = xlsx.sheet('officer')
    # puts "last_row: #{off.last_row}"
    (2..off.last_row).each do |row|
      d = off.row(row)
      ord = d[0].to_i
      amp = d[1] || 'NA' # case amp is nil
      cwt = d[2] || 'NA' # case cwt is nil
      # recode amp == เมือง
      if amp == 'เมือง'
        amp += cwt
      end
      if !@info5.key?(cwt) # count changwat
        @info5[cwt] = 1
      else
        @info5[cwt] += 1
      end

      # count amp in each province
      if @info6.keys.include?(cwt)
        if @info6[cwt].keys.include?(amp)
          @info6[cwt][amp] += 1
        else
          @info6[cwt][amp] = 1 # set count amp in cwt = 1
        end
      else
        @info6[cwt] = {}
        @info6[cwt][amp] = 1
      end
    end

    # display info via views/report.erb
    # save_dop_dat
    # save_dop_dat # @type1 @type2 @type3
    erb :report
  else
    redirect '/upload'
  end
end
