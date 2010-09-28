before do
  headers['Cache-Control'] = 'public, max-age=172800' # Two days
  
  #if !DPC.connect && request.path_info != '/setup' # try to connect
  #  redirect '/setup'
  #end
end

error do
  'Sorry there was a nasty error - ' + request.env['sinatra.error'].name
end

not_found do
  'Sorry - Not Found'
end

get '/setup' do
  session[:time] = Time.new if session[:time].nil?
  
  "Current Time : " + session[:time].inspect
end

['/rebuild/?', '/rebuild/*'].each do |path|
  get path do
    if DPC.connect
      # Fetch from session, reduce Dropbox calls
      session[:galleries] = DPC.get_galleries if session[:galleries].nil?
      galleries = session[:galleries]
      
      p galleries
      
      begin
        Timeout::timeout(20) do
          thread_list = []
          
          galleries.each do |gallery|
            thread_list << Thread.new {
              load_gallery gallery if gallery.directory? && !(options.album_excludes.include? gallery.path)
            }
          end
          
          thread_list.each { |x| x.join }
        end
      rescue Timeout::Error
        puts "Rebuilding took too long. We'll continue after the break."
        
        redirect "/rebuild/#{rand(99999999)}"
      end
    end
    
    redirect '/' 
  end
end

get '/css/style.css' do
  content_type 'text/css', :charset => 'utf-8'
  
  less :'css/style'
end

get '/' do
  @albums = Album.all() # Should make sure the 'not in' is in the query or so .... :conditions => {:path => })
  
  @albums.each { |alb| @albums.delete(alb) if options.album_excludes.include? alb.path }
  
  erb :index
end

get '/gallery/:album' do
  begin
    @album = Album.find(params[:album])
    
  rescue ActiveRecord::RecordNotFound
    redirect '/'
  end
  
  @photos = @album.photos.each

  erb :gallery
end

get '/gallery/:album/image/:id' do 
    begin
      @album = Album.find(params[:album])
      @photo = @album.photos.find(params[:id])
      
    rescue ActiveRecord::RecordNotFound
      redirect back
    end

    erb :image
end

get '/thumb/:id' do 
  content_type 'image/jpeg'
  
  begin
    image = CACHE.get(options.mc_img_s + params[:id])
  rescue Memcached::Error
    image_item = Photo.find(params[:id])
    image = image_item.img_small

    if image.nil? && DPC.connect
      image = DPC.get_image image_item.path

      image_item.img_small = image
      image_item.save
    end
    
     CACHE.set(options.mc_img_s + params[:id], image)
  end
  
  raise Sinatra::NotFound if image == nil

  image
end

get '/image/:id' do 
  content_type 'image/jpeg'
  
  begin
    image = CACHE.get(options.mc_img_l + params[:id])
  rescue Memcached::Error
    image_item = Photo.find(params[:id])
    image = DPC.get_image image_item.path, 'l'

    CACHE.set(options.mc_img_l + params[:id], image)
  end
  
  raise Sinatra::NotFound if image == nil

  image
end