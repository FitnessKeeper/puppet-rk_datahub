require 'spec_helper'
describe 'rk_datahub' do

  context 'with defaults for all parameters' do
    it { should contain_class('rk_datahub') }
  end
end
