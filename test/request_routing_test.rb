ENV['RAILS_ENV'] = 'test'
ENV['RAILS_ROOT'] ||= File.dirname(__FILE__) + '/../../../..'

require 'test/unit'
require File.expand_path(File.join(ENV['RAILS_ROOT'], 'config/environment.rb'))

class TestController < ActionController::Base
  def thing
  end
end

class OtherTestController < ActionController::Base
  def thing
  end
end

class MockRequest < Struct.new(
  :path,
  :subdomains,
  :method,
  :remote_ip,
  :protocol,
  :path_parameters,
  :domain,
  :domain_2,
  :port,
  :content_type,
  :accepts,
  :request_uri
)
end

class RequestRoutingTest < Test::Unit::TestCase
  attr_reader :rs

  def setup
    @rs = ::ActionController::Routing::RouteSet.new
    ActionController::Routing.use_controllers! %w(test) if ActionController::Routing.respond_to? :use_controllers!
    @rs.draw {|m| m.connect ':controller/:action/:id' }
    @request = MockRequest.new(
      '',
      ['www'],
      :post,
      '1.2.3.4',
      'http://',
      '',
      'thing.com',
      'www.thing.com',
      3432,
      'text/html',
      ['*/*'],
      '/'
    )
  end
  
  def test_normal_routes
    assert_raise(ActionController::RoutingError) do
      @rs.recognize(@request)
    end
    
    @request.path = '/test/thing'
    assert(@rs.recognize(@request))
  end
  
  def test_subdomain
    @rs.draw { |m| m.connect 'thing', :controller => 'test', :conditions => { :subdomain => 'www' }  }
    @request.path = '/thing'
    assert(@rs.recognize(@request))

    @request.subdomains = ['sdkg']
    assert_raise(ActionController::RoutingError) do
      @rs.recognize(@request)
    end
  end
  
  def test_protocol
    @rs.draw { |m| m.connect 'thing', :controller => 'test', :conditions => { :protocol => /^https/ }  }
    @request.path = '/thing'
    assert_raise(ActionController::RoutingError) do
      @rs.recognize(@request)
    end
    
    @request.protocol = "https://"
    assert(@rs.recognize(@request))
  end
  
  def test_alternate
    @rs.draw { |m| 
      m.connect 'thing', :controller => 'test', :conditions => { :remote_ip => '1.2.3.4' }  
      m.connect 'thing', :controller => 'other_test', :conditions => { :remote_ip => '1.2.3.5' }
    }
    
    @request.path = '/thing'
    assert(@rs.recognize(@request))
    
    @request.remote_ip = '1.2.3.5'
    assert(@rs.recognize(@request))
  end

  def test_domain_with_long_tld
    @rs.draw { |m| 
      m.connect 'long_tld', :controller => 'test', :conditions => { :domain_2 => 'mydomain.com.au' }
    }
    @request.domain = 'com.au'
    @request.domain_2 = 'mydomain.com.au'

    @request.path = '/long_tld'
    assert(@rs.recognize(@request))
  end
end
