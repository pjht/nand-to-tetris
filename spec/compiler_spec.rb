require_relative "../compiler.rb"
describe "compile" do
  it "handles int definitions" do
    expect(compile("var int number")).to eq [{"number"=>0}, ""]
  end
end
