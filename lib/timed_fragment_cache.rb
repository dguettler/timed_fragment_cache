module ActionController
  module Caching
  
    # Timed Fragment Caching
    # Adds optional expiry to fragment caching which will cache that fragment for the alloted time
    # Works by adding a 'meta' fragment for each timed fragment (inspired by metafragment code in typo
    # http://www.typosphere.org/trac/browser/trunk/vendor/plugins/expiring_action_cache/lib/metafragment.rb)
    # 
    # Works something like this:
    #
    # <% cache 'fragment_name', 10.minutes.from_now do %>
    #  the cached fragment which does something intensive
    # <% end %>
    #
    # This will be cached for 10 minutes before it expires
    #
    # Also adds when_fragment_expired which you can use to only execute code if the fragment is not cached, or has
    # expired:
    #
    # when_fragment_expired 'fragment_name', 10.minutes_from_now do 
    #  # some intensive code
    # end
    #
    # Note that if using the 'when_fragment_expired' in the controller, you don't need the expiry in the call to cache
    # in the template, as 'when_fragment_expired' will expire the fragment for you.
    module TimedFragment
    
      def self.included(base) # :nodoc:     
        base.class_eval do 
          alias_method :cache_erb_fragment_without_expiry, :cache_erb_fragment
          alias_method :cache_erb_fragment, :cache_erb_fragment_with_expiry
        end      
      end
            
      def cache_erb_fragment_with_expiry(block, name = {}, options = nil, expiry = nil)
        unless perform_caching then block.call; return end

        if expiry && fragment_expired?(name)
          expire_and_write_meta(name, expiry)  
        end
        
        cache_erb_fragment_without_expiry(block, name, options)          
      end
    
      def fragment_expired?(name)
        expires = read_meta_fragment(name)
        expires.nil? || expires < Time.now
      end
    
      def read_meta_fragment(name)
        YAML.load(read_fragment(meta_fragment_key(name))) rescue nil
      end    
    
      def write_meta_fragment(name, meta)
        write_fragment(meta_fragment_key(name), YAML.dump(meta))
      end
    
      def meta_fragment_key(name)
        fragment_cache_key(name) + '_meta'
      end
    
      def when_fragment_expired(name, expiry=nil)
        return unless fragment_expired? name
        
        yield
        expire_and_write_meta(name, expiry)
      end
    
      def expire_and_write_meta(name, expiry)
        expire_fragment(name)
        write_meta_fragment(name, expiry) if expiry
      end
    
    end
  end
end

module ActionView
  module Helpers
    module TimedFragmentCacheHelper
    
      def self.included(base) # :nodoc:     
        base.class_eval do 
          alias_method :cache, :cache_with_expiry
        end      
      end    
    
      def cache_with_expiry(name = {}, expires = nil, &block)
        @controller.cache_erb_fragment(block, name, nil, expires)
      end
    
    end
  end
end

ActionController::Base.send :include, ActionController::Caching::TimedFragment
ActionView::Base.send(:include, ActionView::Helpers::TimedFragmentCacheHelper)