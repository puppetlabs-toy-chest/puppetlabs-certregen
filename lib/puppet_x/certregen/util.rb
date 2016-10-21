module PuppetX
  module Certregen
    module Util
      module_function

      def duration(epoch)
        seconds = epoch.to_i
        minutes = (epoch / 60).to_i; seconds %= 60 if minutes > 0
        hours = (minutes / 60).to_i; minutes %= 60 if hours > 0
        days = (hours / 24).to_i;    hours %= 24 if days > 0
        years = (days / 365).to_i;   days %= 365 if years > 0

        list = []
        list << "#{years} #{pluralize('year', years)}" if years > 0
        list << "#{days} #{pluralize('day', days)}" if days > 0
        list << "#{hours} #{pluralize('hour', hours)}" if hours > 0
        list << "#{minutes} #{pluralize('minute', minutes)}" if minutes > 0
        list << "#{seconds} #{pluralize('second', seconds)}" if seconds > 0
        list.join(", ")
      end

      def pluralize(str, count)
        count == 1 ? str : str + 's'
      end
    end
  end
end
