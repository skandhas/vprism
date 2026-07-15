def flow(items)
  items.each do |item|
    next item if item.nil?
    break item if item.done?
  end

  yield items
  return super(items)
end

begin
  run
rescue StandardError => error
  handle(error)
else
  finish
ensure
  cleanup
end

value = maybe() rescue nil
