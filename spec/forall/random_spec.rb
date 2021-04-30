describe Forall::Random do
  before do
    @rnd = Forall::Random.new(seed: 123456789)
  end

  describe "#boolean" do
    it "returns true or false" do
      forall(sampled{|_| }).check{|_| [true, false].include?(@rnd.boolean) }
    end

    it "uses the given random seed" do
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(false)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(true)
      expect(@rnd.boolean).to eq(false)
    end
  end

  describe "#integer" do
    it "hos no required arguments" do
      forall(sampled{|_| }).check{|_| expect(@rnd.integer).to be_a(Integer) }
    end

    it "returns a value within given range" do
      forall(sampled{|rnd| rnd.range(-100..100)}).check do |range|
        @rnd.integer(range).then do |x|
          expect(x).to     be_a(Integer)
          expect(range).to include(x)
        end
      end
    end

    it "it uses the given random seed" do
      expect(@rnd.integer(10..99)).to eq(66)
      expect(@rnd.integer(10..99)).to eq(38)
      expect(@rnd.integer(10..99)).to eq(60)
      expect(@rnd.integer(10..99)).to eq(99)
      expect(@rnd.integer(10..99)).to eq(39)
      expect(@rnd.integer(10..99)).to eq(17)
      expect(@rnd.integer(10..99)).to eq(89)
      expect(@rnd.integer(10..99)).to eq(93)
    end
  end

  describe "#float" do
    it "has no required arguments" do
      forall(sampled{|_| }).check{|_| @rnd.float.is_a?(Float) }
    end

    it "returns a value within the given range" do
      forall(sampled{|rnd| rnd.range(-100.0..100.0)}).check do |range|
        @rnd.float(range).then do |x|
          expect(x).to     be_a(Float)
          expect(range).to include(x)
        end
      end
    end

    it "uses the given random seed" do
      expect(@rnd.float(10.0..99.9)).to eq(57.901688788146565)
      expect(@rnd.float(10.0..99.9)).to eq(58.018880788279375)
      expect(@rnd.float(10.0..99.9)).to eq(55.80881796834886 )
      expect(@rnd.float(10.0..99.9)).to eq(74.14940662527147 )
      expect(@rnd.float(10.0..99.9)).to eq(33.10420605397002 )
      expect(@rnd.float(10.0..99.9)).to eq(77.66715571073766 )
      expect(@rnd.float(10.0..99.9)).to eq(89.46073832691911 )
      expect(@rnd.float(10.0..99.9)).to eq(23.925427336927644)
      expect(@rnd.float(10.0..99.9)).to eq(70.28212456300024 )
      expect(@rnd.float(10.0..99.9)).to eq(67.84571999512615 )
    end
  end

  todo "#string"

  todo "#date"

  todo "#time"

  todo "#datetime"

  describe "#range" do
    context "of integers" do
      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(-100..100)}).check do |range|
          @rnd.range(range).then do |x|
            expect(x).to be_a(Range)
            expect(x.min).to be_a(Integer)
            expect(x.max).to be_a(Integer)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(-100..100)).to eq(56..84  )
        expect(@rnd.range(-100..100)).to eq(-50..-10)
        expect(@rnd.range(-100..100)).to eq(-93..-71)
        expect(@rnd.range(-100..100)).to eq(-21..88 )
        expect(@rnd.range(-100..100)).to eq(-16..-1 )
        expect(@rnd.range(-100..100)).to eq(11..16  )
        expect(@rnd.range(-100..100)).to eq(-18..23 )
        expect(@rnd.range(-100..100)).to eq(7..8    )
      end
    end

    context "of floats" do
      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range(-100.0..100.0)}).check do |range|
          @rnd.range(range).then do |x|
            expect(x).to be_a(Range)
            expect(x.min).to be_a(Float)
            expect(x.max).to be_a(Float)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range(-100.0..100.0)).to eq(6.566604645487345..6.827320997284474  )
        expect(@rnd.range(-100.0..100.0)).to eq(1.9106072710764295..42.71280673030361 )
        expect(@rnd.range(-100.0..100.0)).to eq(-48.60020900117905..50.53872238206375 )
        expect(@rnd.range(-100.0..100.0)).to eq(-69.02018390004974..76.77583609993127 )
        expect(@rnd.range(-100.0..100.0)).to eq(28.68903224722169..34.109287125695744 )
        expect(@rnd.range(-100.0..100.0)).to eq(44.725433856529065..49.745040910752124)
        expect(@rnd.range(-100.0..100.0)).to eq(-80.41829562321206..63.70947866752053 )
        expect(@rnd.range(-100.0..100.0)).to eq(-99.28921818030085..-53.83807606108226)
      end
    end

    context "of characters" do
      it "returns a range within the given range" do
        forall(sampled{|rnd| rnd.range("a".."z")}).check do |range|
          @rnd.range(range).then do |x|
            expect(x).to be_a(Range)
            expect(x.min).to be_a(String)
            expect(x.max).to be_a(String)
            expect(range).to be_cover(x)
          end
        end
      end

      it "uses the given random seed" do
        expect(@rnd.range("a".."z")).to eq("s".."y")
        expect(@rnd.range("a".."z")).to eq("m".."z")
        expect(@rnd.range("a".."z")).to eq("e".."h")
        expect(@rnd.range("a".."z")).to eq("p".."t")
        expect(@rnd.range("a".."z")).to eq("n".."u")
        expect(@rnd.range("a".."z")).to eq("a".."d")
        expect(@rnd.range("a".."z")).to eq("p".."u")
        expect(@rnd.range("a".."z")).to eq("o".."s")
      end
    end
  end

  describe "#sample" do
    context "without a count: argument" do
      context "on sampled{...}" do
        before do
          @input = sampled{|rnd| rnd.integer(-1000..1000) }
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@rnd.sample(@input)).to be_between(-1000, 1000) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq(720 )
          expect(@rnd.sample(@input)).to eq(692 )
          expect(@rnd.sample(@input)).to eq(330 )
          expect(@rnd.sample(@input)).to eq(-654)
          expect(@rnd.sample(@input)).to eq(-203)
          expect(@rnd.sample(@input)).to eq(-508)
          expect(@rnd.sample(@input)).to eq(-225)
          expect(@rnd.sample(@input)).to eq(786 )
        end
      end

      context "on an array" do
        before do
          @input = %w(a b c d e f)
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@input).to include(@rnd.sample(@input)) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq("a")
          expect(@rnd.sample(@input)).to eq("e")
          expect(@rnd.sample(@input)).to eq("c")
          expect(@rnd.sample(@input)).to eq("b")
          expect(@rnd.sample(@input)).to eq("c")
          expect(@rnd.sample(@input)).to eq("f")
          expect(@rnd.sample(@input)).to eq("e")
          expect(@rnd.sample(@input)).to eq("c")
        end
      end

      context "on a range" do
        before do
          @input = 500..599
        end

        it "returns a value from the distribution" do
          forall(sampled{|_| }).check{|_| expect(@input).to include(@rnd.sample(@input)) }
        end

        it "uses the given random seed" do
          expect(@rnd.sample(@input)).to eq(556)
          expect(@rnd.sample(@input)).to eq(528)
          expect(@rnd.sample(@input)).to eq(550)
          expect(@rnd.sample(@input)).to eq(589)
          expect(@rnd.sample(@input)).to eq(590)
          expect(@rnd.sample(@input)).to eq(529)
          expect(@rnd.sample(@input)).to eq(507)
          expect(@rnd.sample(@input)).to eq(579)
        end
      end

      todo "on a non-enumerable value"
    end

    context "with a count: argument" do
      context "on sampled{...}" do
      end

      context "on a range" do
      end

      context "on an array" do
      end

      todo "on a non-enumerable value"
    end
  end

  describe "#shuffle" do
    it "returns a permutation" do
      forall(sampled{|rnd| rnd.array{|_| rnd.integer }}).check do |array|
        expect(@rnd.shuffle(array).sort).to eq(array.sort)
      end
    end

    todo "uses the given random seed"
  end

  describe "#array" do
    context "with unspecified size" do
    end

    context "with fixed size" do
    end

    context "with size range" do
    end
  end

  describe "#hash" do
    context "with unspecified size" do
    end

    context "with fixed size" do
    end

    context "with size range" do
    end
  end

  describe "#set" do
  end
end
